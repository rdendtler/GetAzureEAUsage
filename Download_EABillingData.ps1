Param(
[string]$month,
[string]$type = "detail" #detail for the billing file pricesheet to download the pricesheet
)

$enrollmentNumber = "<enrollmentnumber>"
$accessKey = "<api billing key>"
$baseurl = "https://ea.azure.com" 
$contentType = "application/json;charset=utf-8"
$blobaccountName = "<storage account name>"
$blobaccountKey = "<storage account key>"
$blobcontainerName = "<blob container"
 
#Get the usage list and return the json object 
function GetUsageList([string]$accessKey, [string]$enrollmentNumber) 
{
    $header = @{"authorization"="bearer $accessKey"}
    $url = "$baseurl/rest/$enrollmentNumber/usage-reports";
    Try {
        Write-Host "[Getting   ] Availble Reports for $enrollmentNumber"
        $response = Invoke-WebRequest -Uri $url -Headers $header -Method "Get"
        $json = ($response.Content |  ConvertFrom-Json)
        }
    Catch {
        $errorMessage = $_.Exception.Message 
        $failedItem = $_.Exception.ItemName
        Write-Host "[ERROR    ] $errorMessage $failedItem "
        Break
        }
    return $json
}
#Get the usage report for the specific month.
function GetUsageByMonth([string]$accessKey, [string]$enrollmentNumber, [string]$month, [string]$type) 
{     
    $header = @{"authorization"="bearer $accessKey"}
    $url = "$baseurl/rest/$enrollmentNumber/usage-report";
    #request the data
    Try {
        write-host "[Trying    ] Requesting $type report for the month of $month for enrollment $enrollmentNumber"
        $response = Invoke-WebRequest -Uri "$url`?month=$month&type=$type" `
             -Headers $header `
             -Method "Get" `
             -ContentType $contentType
        }
    Catch {
        $errorMessage = $_.Exception.Message 
        $failedItem = $_.Exception.ItemName
        Write-Host "[ERROR] $errorMessage $failedItem "
        Break
        }
    # Find the first occurence of AccountOwnerId as that is the start of the data
    $report = $response.Content
    # If this is Usage Detail we need to find AccountOnwerID if it's a Pricesheet we find Service
    Write-Host "[Processing] $type file"
    if ($type -eq "detail")
        {
         $pos = $report.IndexOf("AccountOwnerId")
        }
    else
        {
        $pos = $report.IndexOf("Service") 
        }
    # remove the junk data	
    Write-Host "[Processing] Removing junk"
    $data = $report.Substring($pos-1)
	# convert from CSV into an ps variable.  Good spot to do other things with the data here.
    Write-Host "[Converting] to a CSV File"	
    $datacsv = ($data | ConvertFrom-CSV)
    return $datacsv
 } 
function WriteDataToBlob([string]$accountname, [string]$container, [string]$accesskey, [string]$currmonth, $data, [string]$reporttype)
{
    # Write to a local file
    $filename = ".\$($enrollmentNumber)_$($reporttype)_$currmonth.csv"
    Write-Host "[Saving    ] to file $filename"
    $data | Export-Csv -Path $filename -NoTypeInformation
    $context = New-AzureStorageContext -StorageAccountName $accountName -StorageAccountKey $accesskey
    $blobProperties = @{"ContentType" = "text/csv"};
    $fileSend = Set-AzureStorageBlobContent -Force -File $filename -Container $container -BlobType "Block" -Properties $blobProperties -Context $context
    Write-Host "[Uploading ] Wrote $([math]::Truncate($fileSend.Length /1MB)) MB to $($fileSend.ICloudBlob)"
    return
 }
# Start of Main Program  
# If no month specified, get the current month to download.  Otherwise use passed in parameter
if ($month -eq "")
  {
    Write-Host "[Processing] Getting data for current Month"
    $today = Get-Date
    $month = [String] $today.year + "-" + $today.Month
    #Get list of available months
    $json = GetUsageList $accessKey $enrollmentNumber
        if ($today.day  -le 6)
        # Dealing with the data lag.. If the day is less than the 6th, pull this month and last month
        {
        Write-Host "[Processing] Early in Month so we'll grab last month to deal with Data Lag"
        $i = -1
        Do
        {
            $response = GetUsageByMonth $accessKey $enrollmentNumber $json.AvailableMonths[$i].Month $type
            WriteDataToBlob $blobaccountName $blobcontainerName $blobaccountKey $json.AvailableMonths[$i].Month $response $type
            $i--
        }
        while ($i -ge -2)
      }
    else
        {
         $response = GetUsageByMonth $accessKey $enrollmentNumber $json.AvailableMonths[-1].Month $type
            WriteDataToBlob $blobaccountName $blobcontainerName $blobaccountKey $json.AvailableMonths[-1].Month $response $type
        }
  }
else #Pull in the Month requested
  {
    $response = GetUsageByMonth $accessKey $enrollmentNumber $month $type
    WriteDataToBlob $blobaccountName $blobcontainerName $blobaccountKey $month $response $type
  }