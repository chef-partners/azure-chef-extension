
function Poll-AzureOperationStatus($operationId, $subscription) {
  trap [Exception] {echo $_.Exception.Message;exit 1}

  $uri = $subscription.ServiceEndpoint
  $subscriptionId = $subscription.subscriptionId
  $reqUri = "${uri}${subscriptionId}/operations/${operationId}"

  $retryCount = 5
  while ($true) {
    write-host "Checking operation status for id ($operationId)..."
    $reqStatus = Invoke-WebRequest -Method GET -Uri $reqUri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-04-01'}
    $xmlResponse = [xml]$reqStatus.Content
    switch ($xmlResponse.Operation.Status) {
      "Succeeded" {
        write-host "Operation Successfully completed."
        $operationCompleted = $true # exit while
        break
        }
      "InProgress" {
        # Just keep retrying.
        write-host "Operation Inprogress.`nWaiting for 10 seconds..."
        Start-Sleep -s 10
        break
        }
      "Failed" {
        write-host "Operation Failed."
        write-host $reqStatus.Content
        $operationCompleted = $true # exit while
        break
        }
      default {
        write-host "Unknown error."
        write-host $reqStatus.Content
        $operationCompleted = $true # exit while
        break
      }
    }# switch
    if ($operationCompleted) { break }
    if ($retryCount -eq 0) {
      write-host "Number of retries exceeded. Use operation id ($operationId) to check status."
      break
    } else { $retryCount-- }
  }
}