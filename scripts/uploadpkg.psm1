function Upload-ChefPkgToAzure($publishSettingsFile, $storageAccount, $storageContainer, $extensionPackageFile) {
  trap [Exception] {echo $_.Exception.Message;exit 1}

  write-host "Upload-ChefPkgToAzure called with: $publishSettingsFile, $storageAccount, $storageContainer, $extensionPackageFile"

  Import-AzurePublishSettingsFile -PublishSettingsFile $publishSettingsFile

  # If storageAccount does not exists, create it.
  Get-AzureStorageAccount -StorageAccountName $storageAccount
  if ($? -eq $false) {
    write-host "Creating $storageAccount storage account..."
    New-AzureStorageAccount -StorageAccountName  $storageAccount -Label 'ChefExtension' -Description "Store for azure chef extension packages." -Location 'West US'
    write-host "Created storage account - $storageAccount`n`n"
  } else {
    write-host "$storageAccount storage account already exists.`n`n"
  }

  # Get the storage key that needs to be used to create context
  $storageKey = Get-AzureStorageKey -StorageAccountName $storageAccount

  $storageContext = New-AzureStorageContext  -StorageAccountName $storageAccount  -StorageAccountKey $storageKey.Primary

  # Create a storage storageContainer if not present
  # with Blob access - read access to blob data but not container
  Get-AzureStorageContainer -Name $storageContainer -Context $storageContext
  if ($? -eq $false) {
    write-host "Creating $storageContainer storage container..."
    New-AzureStorageContainer $storageContainer -Permission Blob  -Context $storageContext
    write-host "Created container - $storageContainer.`n`n"
  } else {
    write-host "$storageContainer storage container already exists.`n`n"
  }

  # Start the zip package upload to storage.
  Set-AzureStorageBlobContent -Container $storageContainer  -File $extensionPackageFile -Context $storageContext
}

Export-ModuleMember -Function Upload-ChefPkgToAzure