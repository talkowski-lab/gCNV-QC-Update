# gCNV-QC-Update

Updates to the QC step in the gCNV pipeline.

## Filtering Criteria

1. Fail samples with more than 200 calls.
2. Fail samples that have fewer than 200 calls, but more than 35 of those calls
have a QS greater than 20.
3. Dynamically set a QS threshold for each call based on SV type and size and
filter based on that threshold.
