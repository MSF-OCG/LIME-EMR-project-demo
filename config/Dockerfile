FROM ubuntu:latest
WORKDIR /openmrs_config

RUN apt-get -y update
RUN apt-get -y install git

RUN git init
RUN git remote add origin https://github.com/MSF-OCG/LIME-EMR-project-demo.git
RUN git checkout -b 'dev'
RUN git config core.sparsecheckout true
RUN echo distro/ >> .git/info/sparse-checkout
RUN git pull origin dev

ENTRYPOINT ["tail", "-f", "/dev/null"] 