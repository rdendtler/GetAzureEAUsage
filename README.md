# GetAzureEAUsage
Get Azure Enterprise Account Usage using the API.  Download to a file and upload to an Azure Blob Storage

## Introduction 
This powershell script downloads Azure EA Billing data from the REST API and then loads to Blob Storage for further processing. 
Usage: 

`Download-EABilling -month Month in yyyy-mm format -type Detail | Pricesheet`

The script takes into account data lag and if its within the first 5 days of the month it will also download the previoius month's data as well.  The script has two optional parameters
* `-Month yyyy-mm` is the first option.  If NO month is specifid, the current month is used
* `-Type  Detail | Pricesheet ` is the second option.  If not specified, Detail is used, which will download usage detail.  If Pricesheet is specified, then the current month's pricesheet will be downloaded
