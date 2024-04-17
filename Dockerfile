ARG R_VERSION
ARG BIOC_VERSION

FROM ubuntu:jammy

ENV R_VERSION=${R_VERSION:-4.3.3}
ENV BIOC_VERSION=${BIOC_VERSION:-3.18}

# Install a specific version of using posit release of gdebi packages.
RUN export DEBIAN_FRONTEND=noninteractive \ 
  && apt-get update \
  && apt-get -y install --no-install-recommends \
    gdebi-core curl ca-certificates apt-utils apt-file \
  && . /etc/os-release \
  && curl -O https://cdn.rstudio.com/r/${ID}-$(echo $VERSION_ID | sed 's/\.//g' )/pkgs/r-${R_VERSION}_1_amd64.deb \
  && gdebi --n r-${R_VERSION}_1_amd64.deb \
  && apt-get -y clean \
  && apt-get -y purge gdebi \
  && apt-get -y autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && rm r-${R_VERSION}_1_amd64.deb \
  && ln -s /opt/R/${R_VERSION}/bin/R /usr/local/bin/R \
  && ln -s /opt/R/${R_VERSION}/bin/Rscript /usr/local/bin/Rscript

# Setup from https://packagemanager.posit.co/client/#/repos/bioconductor/setup
RUN R_HOME=$(Rscript -e 'R.home()' | sed -e 's/\[1\] //g' | sed -e 's/"//g') \
  && R_PROFILE=$R_HOME/etc/Rprofile.site \
  && . /etc/os-release \
  && echo "options(BioC_mirror = \"https://packagemanager.posit.co/bioconductor\")" >> $R_PROFILE \
  && echo "options(BIOCONDUCTOR_CONFIG_FILE = \"https://packagemanager.posit.co/bioconductor/config.yaml\")" >> $R_PROFILE \
  && echo "options(repos = c(CRAN = \"https://packagemanager.posit.co/cran/__linux__/${VERSION_CODENAME}/latest\"))" >> $R_PROFILE

RUN Rscript - <<EOR
  install.packages(c("BiocManager", "rspm"), repos = "https://cloud.r-project.org", clean = TRUE)
EOR

RUN R_HOME=$(Rscript -e 'R.home()' | sed -e 's/\[1\] //g' | sed -e 's/"//g') \
  && R_PROFILE=$R_HOME/etc/Rprofile.site \
  && mkdir -p $R_HOME/site-library \
  && echo ".library <- \"${R_HOME}/site-library\"" >> $R_PROFILE

RUN Rscript - <<EOR
  rspm::enable()
  BiocManager::install(version = "${BIOC_VERSION}")
  install.packages(c("Seurat", "hdf5", "SoupX", "devtools"), clean = TRUE)
  BiocManager::install(c("SingleR", "celldex", "SingleCellExperiment"), version = "${BIOC_VERSION}")
  devtools::install_github('satijalab/seurat-data')
  devtools::install_github('guokai8/rcellmarker')
  devtools::install_github('immunogenomics/presto')
  devtools::install_github('rx-li/EasyCellType')
EOR
