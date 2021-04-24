FROM ubuntu

#Service principal
ENV SPUSERNAME=""
ENV SPPASSWORD=""
ENV TENANT=""

#Data Lake store
ENV DLS_ACCOUNT_NAME=""
ENV RESOURCE_GROUP=""

#The service you want to allow
ENV SERVICE_NAME="PowerBI"

WORKDIR /app

#Add the script
COPY script.sh .

#We need prips, jq and azure cli
RUN apt-get update \
    && apt-get -y install ca-certificates curl apt-transport-https lsb-release gnupg prips jq \
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null \
    && AZ_REPO=$(lsb_release -cs) \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update \
    && apt-get install azure-cli


ENTRYPOINT [ "/bin/bash","script.sh" ]