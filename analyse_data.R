library(tidyverse)
library(reshape2)

drugs_signatures <- unlist(strsplit(read_file("drugs_signature_ids"), split = "\n"))

prefix <- paste("results", "drugs", sep = "/")
filenames <- paste(paste(drugs_signatures, "Concordant", sep = "-"), "tsv", sep = ".")

files <- paste(prefix, filenames, sep = "/")

metadata <- read_csv("signature_data/id-name-cellline_mapping.csv",
                     col_types = cols(
                       SignatureId = col_character(),
                       Perturbagen = col_character(),
                       CellLine = col_character()
                     ))

col_spec <- cols(
  similarity = col_double(),
  pValue = col_double(),
  nGenes = col_double(),
  treatment = col_character(),
  perturbagenID = col_character(),
  time = col_character(),
  signatureid = col_character(),
  cellline = col_character(),
  Source_Signature = col_character()
)

dfs <- list()

for (i in 1:length(files)) {
  df <- read_tsv(files[i], col_types = col_spec)
  dfs[[i]] <- df
}

df <- reduce(dfs, bind_rows)

drugs <- c("Fluoxetine", "Bupropion", "Paroxetine", "Dexamethasone", "Chloroquine")

complete <- inner_join(df, metadata, by = c("Source_Signature" = "SignatureId", "cellline" = "CellLine")) %>% 
  mutate(Perturbagen = str_to_title(Perturbagen)) %>% 
  rename(perturbagen = Perturbagen) %>% 
  mutate(perturbagen = if_else(perturbagen == "N-Methylparoxetine", "Paroxetine", perturbagen),
         perturbagen = if_else(perturbagen == "Dexamethasone Acetate", "Dexamethasone", perturbagen),
         perturbagen = if_else(perturbagen == "Dexamethasone 21-Acetate", "Dexamethasone", perturbagen)) %>% 
  filter(perturbagen %in% drugs)

filter_data <- function(data, cell_line) {
    dataframe <- data
    output <- dataframe %>%
    filter(cellline == cell_line) %>%
    group_by(cellline, treatment, perturbagen) %>%
    filter(abs(similarity) == max(abs(similarity))) %>%
    ungroup() %>% 
    select(signatureid, treatment, perturbagen, similarity, pValue, cellline)
    return(output)
  }

analysed <- complete %>% 
  group_by(cellline, treatment, perturbagen) %>% 
  filter(abs(similarity) == max(abs(similarity)))

cell_lines <- unique(analysed$cellline)

for (cell in cell_lines) {
  outfile <- paste("results", paste(paste(cell, "result", sep = "-"), "csv", sep = "."), sep = "/")
  
  analysed %>% 
    filter(cellline == cell) %>% 
    select(perturbagen, treatment, cellline, similarity) %>% 
    write_csv(outfile)
}

result_files <- list.files("results/", pattern = "result")

all_results <- analysed %>% 
  select(perturbagen, treatment, cellline, similarity)

write_csv(all_results, "results/all_results.csv")


all_averaged <- all_results %>% 
  group_by(perturbagen, treatment) %>% 
  summarise(mean_similarity = mean(similarity))

write_csv(all_averaged, "results/all_averaged.csv")

cell_line_report <- function(data, gene, cell_lines) {
  d <- data %>% 
    filter(treatment == gene,
           cellline %in% cell_lines) %>% 
    ungroup() %>% 
    select(-treatment) %>% 
    arrange(cellline, similarity)
  
  outfile <- paste("results", paste(gene, "csv", sep = "."), sep = "/")
  outfile_cross <- paste("results", paste(paste(gene, "cross", sep = "-"), "csv", sep = "."), sep = "/")
  
  write_csv(d, outfile)
  
  dcross <- dcast(d, cellline ~ perturbagen)
  
  write.csv(dcross, outfile_cross)
}

cell_line_report(all_results, "IL6", cell_lines)
cell_line_report(all_results, "IL6R", cell_lines)
cell_line_report(all_results, "IL6ST", cell_lines)
cell_line_report(all_results, "NFKB1", cell_lines)
cell_line_report(all_results, "NFKB2", cell_lines)
cell_line_report(all_results, "RELA", cell_lines)
cell_line_report(all_results, "RELB", cell_lines)
cell_line_report(all_results, "TNF", cell_lines)