FROM alpine:3.17.1

ARG version=2.28.0
ARG path=/usr/local/bin

LABEL cli_version="${version}"
LABEL official_documentation="https://cli.github.com/"
LABEL official_repository="https://github.com/cli/cli"

ENV TOKEN=$TOKEN

# Install packages
RUN apk add --no-cache git openssh

# Create directory
RUN mkdir /gh
WORKDIR /gh

# Download GitHub CLI
RUN wget https://github.com/cli/cli/releases/download/v${version}/gh_${version}_linux_amd64.tar.gz
RUN tar -xvzf gh_${version}_linux_amd64.tar.gz

# Copy gh to /usr/local/bin
RUN mv /gh/gh_${version}_linux_amd64/bin/gh ${path}/

# Remove folder and GitHub CLI .tar.gz
RUN rm -f gh_${version}_linux_amd64.tar.gz
RUN rm -rf /gh/gh_${version}_linux_amd64

# Run GitHub CLI
ENTRYPOINT [ "gh" ]
CMD [ "run download --repo MSF-OCG/LIME-EMR-project-demo -n configuration-artifact" ]