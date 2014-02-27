
$chefExtensionRoot = ("{0}{1}" -f (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition), "\..")

# Returns a json object from json file
function readJsonFromFile
{
  (Get-Content $args[0]) -join "`n" | ConvertFrom-Json
}

# returns the handler settings read from the latest settings file
function getHandlerSettings
{
  # XXX: read latest settings file
  $runtimeSettingsJson = readJsonFromFile $chefExtensionRoot"\RuntimeSettings\1.settings"
  $runtimeSettingsJson.runtimeSettings[0].handlerSettings
}

function getMachineOS
{
  # XXX: Implement
  "2008r2"
}

function getMachineArch
{
  # XXX: Implement
  "x86_64"
}