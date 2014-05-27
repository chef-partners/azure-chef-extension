function Publish-ChefPkg($publishSettingsFile, $subscriptionName, $publishUri, $definitionXmlFile, $postOrPut) {
  trap [Exception] {echo $_.Exception.Message;exit 1}

  write-host "Publish-ChefPkg called with: $publishSettingsFile, `'$subscriptionName`', $publishUri, $definitionXmlFile, $postOrPut"

  Import-AzurePublishSettingsFile -PublishSettingsFile $publishSettingsFile

  $subscription = Get-AzureSubscription -SubscriptionName $subscriptionName

  $bodyxml = Get-Content $definitionXmlFile

  # Trigger the publish
  $req = Invoke-WebRequest -Method $postOrPut -Uri $publishUri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-04-01'} -Body $bodyxml -ContentType application/xml;

  # retry status retrieval for few times.
  $uri = $subscription.ServiceEndpoint.AbsoluteUri
  $subscriptionId = $subscription.subscriptionId
  $reqId = $req.Headers['x-ms-request-id']
  $reqUri = "${uri}${subscriptionId}/operations/${reqId}"
  $retryCount = 5
  while ($true) {
    write-host "Checking publish status with operation id ($reqId)..."
    $reqStatus = Invoke-WebRequest -Method GET -Uri $reqUri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-04-01'}
    $xmlResponse = [xml]$reqStatus.Content
    switch ($xmlResponse.Operation.Status) {
      "Succeeded" {
        write-host "Successfully published."
        $retryCount = 0 # exit while
        break
        }
      "InProgress" {
        # Just keep retrying.
        write-host "Publishing Inprogress.`nWaiting for 10 seconds..."
        Start-Sleep -s 10
        break
        }
      "Failed" {
        write-host "Failed publishing."
        write-host $reqStatus.Content
        $retryCount = 0 # exit while
        break
        }
      default {
        write-host "Unknown error during publishing."
        write-host $reqStatus.Content
        $retryCount = 0 # exit while
        break
      }
    }# switch
    if ($retryCount -eq 0) { break } else { $retryCount-- }
  }
}

Export-ModuleMember -Function Publish-ChefPkg