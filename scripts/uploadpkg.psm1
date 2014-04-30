function Upload-ChefPkgToAzure($publishSettingsFile, $storageAccount, $storageContainer) {
  trap [Exception] {echo $_.Exception.Message;exit 1}

  write-host "Upload-ChefPkgToAzure called with: $publishSettingsFile, $storageAccount, $storageContainer"

}

Export-ModuleMember -Function Upload-ChefPkgToAzure