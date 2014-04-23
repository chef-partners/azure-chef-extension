#
# To run pester tests you have to clone git-repo: $git clone https://github.com/pester/Pester
# Then open powershell terminal and do:
# To import pester
# PS>Import-Module <pester_git_repo_path>/Pester.psm1
#
# To run pester tests
# PS>Invoke-Pester -relative_path <azure-chef-extension-repo-path>/spec/shared.Tests.ps1
#
# For more info: http://johanleino.wordpress.com/2013/09/13/pester-unit-testing-for-powershell/

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")

. $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\$sut")

describe "#Read-JsonFile" {
  it "returns correct values " {
    $handlerSettingsFileName = "testhandlerSettingsFileName"
    mock Get-HandlerSettingsFileName {return $handlerSettingsFileName}
    $handlerSettings = @{"protectedSettings" = "testprotectedSettings"; "protectedSettingsCertThumbprint" = "testprotectedSettingsCertThumbprint"; "publicSettings" = @{"client_rb"= "testclientrb"; "runList" = "testrunlist"}}
    $handlerEnvironment = @{"logFolder" = "testlogFolder"; "statusFolder" = "teststatusFolder"; "heartbeatFile" = "testheartbeatFile" }
    mock Get-HandlerSettings {return $handlerSettings}
    mock Get-HandlerEnvironment {return $handlerEnvironment}

    $json_handlerSettingsFileName, $json_handlerSettings, $json_protectedSettings,  $json_protectedSettingsCertThumbprint, $json_client_rb , $json_runlist, $json_chefLogFolder, $json_statusFolder, $json_heartbeatFile = Read-JsonFile

    $json_handlerSettingsFileName | Should Be $handlerSettingsFileName
    $json_handlerSettings | Should Be $handlerSettings
    $json_protectedSettings | Should Be $handlerSettings.protectedSettings
    $json_protectedSettingsCertThumbprint | Should Be $handlerSettings.protectedSettingsCertThumbprint
    $json_client_rb | Should Be $handlerSettings.publicSettings.client_rb
    $json_runlist | Should Be $handlerSettings.publicSettings.runList
    $json_chefLogFolder | Should Be $handlerEnvironment.logFolder
    $json_statusFolder | Should Be $handlerEnvironment.statusFolder
    $json_heartbeatFile | Should Be $handlerEnvironment.heartbeatFile
  }
}

describe "#Read-JsonFileUsingRuby" {
  it "returns correct values" {
    $handlerSettingsFilePath = "testhandlerSettingsFilePath"
    mock Get-HandlerSettingsFilePath { return $handlerSettingsFilePath }

    $handlerEnvironmentFilePath = "testhandlerEnvironmentFilePath"
    mock Get-HandlerEnvironmentFilePath { return $handlerEnvironmentFilePath }

    $handlerSettings = @{"protectedSettings" = "testprotectedSettings"; "protectedSettingsCertThumbprint" = "testprotectedSettingsCertThumbprint"; "publicSettings" = @{"client_rb"= "testclientrb"; "runList" = "testrunlist"}}
    $handlerEnvironment = @{"logFolder" = "testlogFolder"; "statusFolder" = "teststatusFolder"; "heartbeatFile" = "testheartbeatFile" }

    mock Get-JsonValueUsingRuby {return $handlerSettings } -ParameterFilter { $json_handlerSettingsFileName -eq $handlerSettingsFilePath -and $args[0] -eq "runtimeSettings" -and $args[1] -eq "0" -and $args[2] -eq "handlerSettings" }
    mock Get-JsonValueUsingRuby {return $handlerSettings.protectedSettings } -ParameterFilter { $json_handlerSettingsFileName -eq $handlerSettingsFilePath -and $args[0] -eq "runtimeSettings" -and $args[1] -eq "0" -and $args[2] -eq "handlerSettings" -and $args[3] -eq "protectedSettings" }
    mock Get-JsonValueUsingRuby {return $handlerSettings.protectedSettingsCertThumbprint } -ParameterFilter { $json_handlerSettingsFileName -eq $handlerSettingsFilePath -and $args[0] -eq "runtimeSettings" -and $args[1] -eq "0" -and $args[2] -eq "handlerSettings" -and $args[3] -eq "protectedSettingsCertThumbprint" }
    mock Get-JsonValueUsingRuby {return $handlerSettings.publicSettings.client_rb } -ParameterFilter { $json_handlerSettingsFileName -eq $handlerSettingsFilePath -and $args[0] -eq "runtimeSettings" -and $args[1] -eq "0" -and $args[2] -eq "handlerSettings" -and $args[3] -eq "publicSettings" -and $args[4] -eq "client_rb"}
    mock Get-JsonValueUsingRuby {return $handlerSettings.publicSettings.runList } -ParameterFilter { $json_handlerSettingsFileName -eq $handlerSettingsFilePath -and $args[0] -eq "runtimeSettings" -and $args[1] -eq "0" -and $args[2] -eq "handlerSettings" -and $args[3] -eq "publicSettings" -and $args[4] -eq "runList" }
    mock Get-JsonValueUsingRuby {return $handlerEnvironment.logFolder } -ParameterFilter { $json_handlerEnvironmentFileName -eq $handlerEnvironmentFilePath -and $args[0] -eq "handlerEnvironment" -and $args[1] -eq "logFolder" }
    mock Get-JsonValueUsingRuby {return $handlerEnvironment.statusFolder } -ParameterFilter { $json_handlerEnvironmentFileName -eq $handlerEnvironmentFilePath -and $args[0] -eq "handlerEnvironment" -and $args[1] -eq "statusFolder" }
    mock Get-JsonValueUsingRuby {return $handlerEnvironment.heartbeatFile } -ParameterFilter { $json_handlerEnvironmentFileName -eq $handlerEnvironmentFilePath -and $args[0] -eq "handlerEnvironment" -and $args[1] -eq "heartbeatFile" }

    $json_handlerSettingsFileName, $json_handlerSettings, $json_protectedSettings,  $json_protectedSettingsCertThumbprint, $json_client_rb , $json_runlist, $json_chefLogFolder, $json_statusFolder, $json_heartbeatFile = Read-JsonFileUsingRuby

    $json_handlerSettingsFileName | Should Be $handlerSettingsFilePath
    $json_handlerSettings | Should Be $handlerSettings
    $json_protectedSettings | Should Be $handlerSettings.protectedSettings
    $json_protectedSettingsCertThumbprint | Should Be $handlerSettings.protectedSettingsCertThumbprint
    $json_client_rb | Should Be $handlerSettings.publicSettings.client_rb
    $json_runlist | Should Be $handlerSettings.publicSettings.runList
    $json_chefLogFolder | Should Be $handlerEnvironment.logFolder
    $json_statusFolder | Should Be $handlerEnvironment.statusFolder
    $json_heartbeatFile | Should Be $handlerEnvironment.heartbeatFile
  }
}

describe "#Get-HandlerSettings" {
  it "returns handlerSettings" {
    mock Get-HandlerSettingsFileName
    $runtimeSettingsJson = @{"runtimeSettings" = @(@{"handlerSettings" = "testhandlerSettings"})}
    mock Read-JsonFromFile { return $runtimeSettingsJson}

    $handlerSettings = Get-HandlerSettings
    $handlerSettings | Should Be $runtimeSettingsJson.runtimeSettings[0].handlerSettings
    Assert-MockCalled  Get-HandlerSettingsFileName -Times 1
  }
}

describe "#Write-ChefStatus" {
  it "write status to file" {
    # PS 2.0 not supports ConvertTo-Json. Added this empty function for PS 2.0, So test can run on PS 2.0 as well.
    function ConvertTo-Json {}

    $json_handlerSettingsFileName = "0.settings"
    $json_statusFolder = $env:tmp
    $testStatusFile = "$json_statusFolder\\0.status"
    mock Get-PowershellVersion {return 3}
    mock ConvertTo-Json {return @{ "version"="1.0";"timestampUTC"="2014-04-23T04:03:54Z"; "status" = "teststatus"}}
    mock Get-Date {return "2014-04-23T09:41:13Z"}
    mock Out-File
    $operation = "installing-chef"
    $statusType = "transitioning"
    $message = "installing Chef"
    Write-ChefStatus ($operation, $statusType, $message)
    Assert-MockCalled ConvertTo-Json -Times 1
    Assert-MockCalled Get-Date -Times 1
    Assert-MockCalled Out-File -Times 1 -ParameterFilter { $filePath -eq $testStatusFile }
  }
}

describe "#Update-ChefExtensionRegistry" {
  context "when registry entry exists" {
    it "Update the value" {
      $testPath = "HKLM:\Software\Chef\AzureExtension"
      $testvalue = "X"
      mock Test-Path {return $true }
      mock New-Item
      mock New-ItemProperty
      mock Get-ItemProperty {return @{"Status" = "Update"}}

      Update-ChefExtensionRegistry $testvalue

      Assert-MockCalled New-Item -Times 0
      Assert-MockCalled Test-Path -Times 1 -ParameterFilter {$Path -eq $testPath -and $PathType -eq "Container"}
      Assert-MockCalled New-ItemProperty -Times 1 -ParameterFilter {$Path -eq $testPath -and $Name -eq "Status" -and $Value -eq $testvalue}
      Assert-MockCalled Get-ItemProperty -Times 1 -ParameterFilter {$Path -eq $testPath}
    }
  }

  context "when registry entry not exists" {
    it "Add new registry entry" {
      $testPath = "HKLM:\Software\Chef\AzureExtension"
      $testvalue = "X"
      mock Test-Path {return $false }
      mock New-Item
      mock New-ItemProperty
      mock Get-ItemProperty {return @{"Status" = "Update"}}

      Update-ChefExtensionRegistry $testvalue

      Assert-MockCalled New-Item -Times 1 -ParameterFilter {$Path -eq $testPath -and $Name -eq "Status" -and $Value -eq $testvalue}
      Assert-MockCalled Test-Path -Times 1 -ParameterFilter {$Path -eq $testPath -and $PathType -eq "Container"}
      Assert-MockCalled New-ItemProperty -Times 1 -ParameterFilter {$Path -eq $testPath -and $Name -eq "Status" -and $Value -eq $testvalue}
      Assert-MockCalled Get-ItemProperty -Times 1 -ParameterFilter {$Path -eq $testPath}
    }
  }
}

describe "#Test-ChefExtensionRegistry" {
  context "when registry entry exists" {
    it "return true" {
      $testPath = "HKLM:\Software\Chef\AzureExtension"
      $testvalue = "updated"
      $testName = "Status"

      mock Test-Path {return $true }
      mock Get-ItemProperty {return @{"Status" = "updated"}}

      $result = Test-ChefExtensionRegistry

      $result | Should Be $true
      Assert-MockCalled Test-Path -Times 1 -ParameterFilter {$Path -eq $testPath -and $PathType -eq "Container"}
      Assert-MockCalled Get-ItemProperty -Times 1 -ParameterFilter {$Path -eq $testPath}
    }
  }

  context "when registry entry not exists" {
    it "return false" {
      $testPath = "HKLM:\Software\Chef\AzureExtension"
      $testvalue = "updated"
      $testName = "Status"

      mock Test-Path {return $false }
      mock Get-ItemProperty {return @{"Status" = "updated"}}

      $result = Test-ChefExtensionRegistry

      $result | Should Be $false
      Assert-MockCalled Test-Path -Times 1 -ParameterFilter {$Path -eq $testPath -and $PathType -eq "Container"}
      Assert-MockCalled Get-ItemProperty -Times 0
    }
  }

  context "when registry entry exists and its status value not updated" {
    it "return false" {
      $testPath = "HKLM:\Software\Chef\AzureExtension"
      $testvalue = "updated"
      $testName = "Status"

      mock Test-Path {return $true }
      mock Get-ItemProperty {return @{"Status" = ""}}

      $result = Test-ChefExtensionRegistry

      $result | Should Be $false
      Assert-MockCalled Test-Path -Times 1 -ParameterFilter {$Path -eq $testPath -and $PathType -eq "Container"}
      Assert-MockCalled Get-ItemProperty -Times 1 -ParameterFilter {$Path -eq $testPath}
    }
  }
}