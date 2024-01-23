###############################################################################
# Filter the output of gCNV using quality metrics.
# Usage: Rscript gcnv_qc.R INPUT OUTPUT
#
# The input should be the BED file output by the original gCNV pipeline.
###############################################################################
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(stringr))

ARGV <- commandArgs(trailingOnly=TRUE)
if (length(ARGV) != 2) {
    stop("Usage: Rscript gcnv_qc.R INPUT OUTPUT")
}
CALLS_FILE <- ARGV[1]
OUTPUT_FILE <- ARGV[2]

calls <- fread(CALLS_FILE, sep='\t')
calls[, c("PASS_SAMPLE", "PASS_QS", "PASS_FREQ", "HIGH_QUALITY") := list(NULL)]
calls[, c("vaf", "vac") := list(NULL)]

###############################################################################
# Compute variant counts and frequencies
###############################################################################
new_calls <- calls[, session_id := .I][, c("chr", "start", "end", "session_id")]
gcnv_uniq <- unique(new_calls, by=c("chr", "start", "end"))
setnames(gcnv_uniq, "session_id", "name")
gcnv_uniq[, c("sample", "svtype") := .("SAMPLE", "TYPE")]

on.exit(file.remove("unique.bed", "unique_clustered.bed"), add=TRUE)

fwrite(gcnv_uniq, "unique.bed", col.names=FALSE, sep="\t")
rtn <- system2("svtk", args=c("bedcluster", "unique.bed", "unique_clustered.bed"))
if (rtn != 0) {
    stop("clustering failed")
}

svtk_master <- fread("unique_clustered.bed")
setnames(svtk_master, "#chrom", "chr")
setkey(svtk_master, call_name)


#' Split the call names in the SVTK bedcluster output and reshape to long.
#'
#' The svtk bedcluster command produces an output in which call names
#' (from the same cluster?) are merged into a single table entry. We split
#' them so each gets its own row.
split_pivot_calls <- function(x) {
    calls <- str_split(x$call_name, ",")
    lens <- vapply(calls, FUN=length, FUN.VALUE=integer(1))
    expanded <- data.table(call_name=rep(x$call_name, lens), tmp=unlist(calls))
    setkey(expanded, call_name)
    merged <- x[expanded, on="call_name"][, !"call_name"]
    setnames(merged, "tmp", "call_name")
    return(merged)
}

svtk_master <- split_pivot_calls(svtk_master)[, c("name", "call_name")]
setnames(svtk_master, "name", "clustered_id")
svtk_master[, "call_name" := as.integer(call_name)]

setkey(svtk_master, call_name)
setkey(gcnv_uniq, name)
gcnv_uniq <- gcnv_uniq[svtk_master, on=c("name"="call_name")]
gcnv_uniq[, clustered_id := str_replace(clustered_id, "prefix_", "variant_")]
cluster_calls <- gcnv_uniq[new_calls, on=c("chr", "start", "end"), mult="first", nomatch=NA]

ids <- cluster_calls$session_id
calls[ids, "variant_name" := cluster_calls$clustered_id]

site_count <- table(calls$variant_name)
site_freq <- site_count / length(unique(calls$sample))

mat <- match(calls$variant_name, names(site_freq))
calls$sf <- as.numeric(site_freq[mat])
calls$sc <- as.numeric(site_count[mat])


autosomes <- calls[chr %in% paste0("chr", 1:22)]
###############################################################################
# Sample-level filtering
# 1. Samples that have more than 200 calls fail.
# 2. Samples that have 200 or fewer calls, but more than 35 of those calls
#    have a QS greater than 20 fail. This is a filtering step because
#    given the generally deleterious effect of rare CNV's, you would not
#    expect a sample to have many high-quality calls.
#
# Call-level filtering
# Each call has a different QS threshold based on the size of the CNV and the
# type of the CNV.
# * Larger events have a higher threshold than smaller events.
# * Deletions have a higher threshold than duplications.
# * Homozygous deletions have a higher threshold than heterozygous deletions.
###############################################################################
qs_metrics <- autosomes[, list(n=.N, qs20=sum(QS > 20)), by="sample"]
qs_metrics[, PASS_SAMPLE := n <= 200 & qs20 <= 35]
calls <- calls[qs_metrics[, c("sample", "PASS_SAMPLE")], on="sample"]

thresh_del <- pmin(pmax(calls$NP * 10, 100), 1000)
thresh_dup <- pmin(pmax(calls$NP * 4, 50), 400)
thresh <- thresh_del
thresh[calls$svtype == "DUP"] <- thresh_dup[calls$svtype == "DUP"]
thresh[calls$CN == 0] <- pmax(thresh_del[calls$CN == 0], 400)

calls$PASS_QS <- calls$QS >= thresh
calls$PASS_FREQ <- calls$sf < 0.01
calls$HIGH_QUALITY <- calls$NP >= 3 & calls$PASS_SAMPLE & calls$PASS_QS & calls$PASS_FREQ

fwrite(calls, quote=FALSE, sep="\t", file=OUTPUT_FILE)
