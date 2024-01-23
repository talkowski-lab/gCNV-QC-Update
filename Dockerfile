FROM r-base:4.3.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bedtools \
        cython3 \
        git \
        libhts-dev \
        libhts3 \
        python3-boto3 \
        python3-natsort \
        python3-numpy \
        python3-pandas \
        python3-pip \
        python3-pybedtools \
        python3-pysam \
        python3-scipy \
        python3-sklearn \
    && rm -rf /var/lib/apt/lists/*

RUN install2.r --error data.table stringr \
    && rm -rf /tmp/downloaded_packages

# --break-system-packages allows for installing into the global Python
# installation, which should be ok in a Docker image.
#
# The author of the svtk package did not properly mark all the sub-packages
# with __init__.py files so when pip installs it, not all of the necessary
# sub-packages are copied over to the destination directory. This means that
# the package must be installed as an editable package which keeps the
# source directory in place and allows the svtk to access all of its own
# sub-packages.
RUN cd /opt \
    && git clone 'https://github.com/talkowski-lab/svtk.git' \
    && pip3 install --break-system-packages --editable ./svtk

RUN mkdir /scripts
COPY --chmod=644 gcnv_qc.R /scripts/gcnv_qc.R

CMD ["bash"]
