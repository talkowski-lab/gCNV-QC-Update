FROM rocker/r-ver:4.3.2

RUN R -q -e 'install.packages("data.table", INSTALL_opts=c("--no-docs"))'
RUN mkdir /scripts
COPY --chmod=644 gcnv_qc.R /scripts/
