function Publish-ChefPkg($publishSettingsFile, $publishUri, $definitionXmlFile) {
  trap [Exception] {echo $_.Exception.Message;exit 1}

  write-host "Publish-ChefPkg called with: $publishSettingsFile, $publishUri, $definitionXmlFile"

}

Export-ModuleMember -Function Publish-ChefPkg