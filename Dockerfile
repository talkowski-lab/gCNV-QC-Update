FROM r-base:4.3.2

RUN install2.r --error data.table stringr \
    rm -rf /tmp/downloaded_packages
RUN mkdir /scripts
COPY --chmod=644 gcnv_qc.R /scripts/gcnv_qc.R
