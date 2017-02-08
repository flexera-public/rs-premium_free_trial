#!/bin/sh

echo "This script creates a storage account and copies over the following two custom images from engineering for Azure RM Central US ONLY:
https://armwestus.blob.core.windows.net/system/Microsoft.Compute/Images/vhds/CustomImage_Windows-2008R2_x64_v2016.07.27_RightLink_53705a2-save-osDisk.vhd
https://armwestus.blob.core.windows.net/system/Microsoft.Compute/Images/vhds/CustomImage_Windows-2012R2_x64_v2016.07.27_RightLink_53705a2-save-osDisk.vhd

Also you must have already done:
azure login
azure account list
and identified the 'ENABLED' azure accounts you'll be using

before running the script.

Continue? (Y/N)"

read resp

if [ $resp != "Y" ]
then
	echo "EXITING."
	exit
fi

if [ $# -ne 2 ] 
then
	echo "USAGE: $0 <RS ACCOUNT NUM> <AZURE ACCOUNT ID>"
	exit
fi

RS_ACCOUNT_NUMBER=${1}
AZURE_ACCOUNT_ID=${2}

rsc -a $RS_ACCOUNT_NUMBER cm15 create /api/placement_groups "placement_group[cloud_href]=/api/clouds/3526" "placement_group[name]=rspft$RS_ACCOUNT_NUMBER"

azure account set ${AZURE_ACCOUNT_ID}

storage_key=`azure storage account keys list --resource-group rs-default-centralus rspft${RS_ACCOUNT_NUMBER} | grep key1 | tr -s ' ' ';' | cut -d ";" -f3`

azure storage container create --account-name rspft${RS_ACCOUNT_NUMBER} --account-key ${storage_key} system

azure storage blob copy start --source-uri https://armwestus.blob.core.windows.net/system/Microsoft.Compute/Images/vhds/CustomImage_Windows-2008R2_x64_v2016.07.27_RightLink_53705a2-save-osDisk.vhd --dest-account-name rspft${RS_ACCOUNT_NUMBER} --dest-account-key ${storage_key} --dest-container system  

azure storage blob copy start --source-uri https://armwestus.blob.core.windows.net/system/Microsoft.Compute/Images/vhds/CustomImage_Windows-2012R2_x64_v2016.07.27_RightLink_53705a2-save-osDisk.vhd --dest-account-name rspft${RS_ACCOUNT_NUMBER} --dest-account-key ${storage_key} --dest-container system  


