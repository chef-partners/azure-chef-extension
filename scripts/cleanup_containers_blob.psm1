function Remove-ContainersBlobs($publishSettingsFile, $subscriptionName, $storageAccount, $storageContainer, $date)
{
  trap [Exception] {echo $_.Exception.Message;exit 1}

  Import-AzurePublishSettingsFile -PublishSettingsFile $publishSettingsFile
  Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccount

  $blobs = Get-AzureStorageBlob -Container $storageContainer
  $blobs | ForEach-Object {
    if (($_.LastModified.Date -le (Get-Date $date)) -and ($_.Name -like "ChefExtensionHandler*")) {
      Remove-AzureStorageBlob -Container $storageContainer -Blob $_.Name
      write-host "Removed Blob: $_.Name"
    }
  }
}

Export-ModuleMember -Function Remove-ContainersBlobs