
function Get-CurrentScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Get-CurrentScriptDirectory

Import-Module "$scriptDir\shared.psm1"

function Delete-ChefPkg($publishSettingsFile, $subscriptionName, $deleteUri) {
  trap [Exception] {echo $_.Exception.Message;exit 1}

  write-host "Delete-ChefPkg called with: $publishSettingsFile, `'$subscriptionName`', $deleteUri"

  $subscription = Get-AzureSubscription -SubscriptionName $subscriptionName -ExtendedDetails

  $req = Invoke-WebRequest -Method DELETE -Uri $deleteUri -Certificate $subscription.Certificate -Headers @{'x-ms-version'='2014-04-01'} -Body $bodyxml -ContentType application/xml;

  Poll-AzureOperationStatus $req.Headers['x-ms-request-id'] $subscription
}

Export-ModuleMember -Function Delete-ChefPkg