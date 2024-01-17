###############################################################################
# Filter the output of gCNV using quality metrics.
# Usage: Rscript gcnv_qc.R INPUT OUTPUT
#
# The input should be the BED file output by the original gCNV pipeline.
###############################################################################
suppressPackageStartupMessages(library(data.table))

CALLS_FILE <- commandArgs(trailingOnly=TRUE)[1]
OUTPUT_FILE <- commandArgs(trailingOnly=TRUE)[2]

calls <- fread(CALLS_FILE, sep='\t')
calls[, c("PASS_SAMPLE", "PASS_QS", "PASS_FREQ", "HIGH_QUALITY") := list(NULL)]

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
