#!/bin/bash

MICROSOFT_IP_RANGES_URL="https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519"
JSON_FILE_NAME="azure-public-ips.json"

#login first
az login --service-principal -u $SPUSERNAME -p $SPPASSWORD --tenant $TENANT

#Get the last version of the Public Azure IP ranges
#https://stackoverflow.com/questions/28798014/is-there-a-way-to-automatically-and-programmatically-download-the-latest-ip-rang
UPDATED_FILE=$(curl -Lfs ${MICROSOFT_IP_RANGES_URL} | grep -Eoi '<a [^>]+>' | grep -Eo 'href="[^\"]+"' | grep "download.microsoft.com/download/" | grep -m 1 -Eo '(http|https)://[^"]+')
echo last version of the Azure Public IP Ranges ${UPDATED_FILE}
curl $UPDATED_FILE -o $JSON_FILE_NAME

#Delete all firewall rules
echo "First, we delete all firewall rules for $DLS_ACCOUNT_NAME in $RESOURCE_GROUP"

for ruleName in $(az dls account firewall list --account $DLS_ACCOUNT_NAME -g $RESOURCE_GROUP | jq -r '.[].name'); do    
    echo "Deleting rule $ruleName"    
    az dls account firewall delete --account $DLS_ACCOUNT_NAME -g $RESOURCE_GROUP --firewall-rule-name $ruleName
done

echo "Now, we added the new rules from $JSON_FILE_NAME"

COUNTER=0

for ipRange in $(cat ${JSON_FILE_NAME} | jq '.values[] | select(.name=="PowerBI") | .properties.addressPrefixes' | jq -r ".[]"); do
    COUNTER=$(($COUNTER + 1))
    echo Checking if $ipRange is IPv4
    FIRST_IP=$(prips $ipRange | head -n 1)

    if [[ $FIRST_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "success! Try to add it to the firewall"
        #https://docs.microsoft.com/en-us/cli/azure/dls/account/firewall?view=azure-cli-latest
        az dls account firewall create --account $DLS_ACCOUNT_NAME -g $RESOURCE_GROUP --firewall-rule-name "Rule_$COUNTER" --start-ip-address $FIRST_IP --end-ip-address $(prips $ipRange | tail -n 1)
    else
        echo "fail"
    fi

done

echo "Done!"