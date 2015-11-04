#
# To run pester tests you have to clone git-repo: $git clone https://github.com/pester/Pester
# Then open powershell terminal and do:
# To import pester
# PS>Import-Module <pester_git_repo_path>/Pester.psm1
#
# To run pester tests
# PS>Invoke-Pester -relative_path <azure-chef-extension-repo-path>/spec/chef-install.Tests.ps1
#
# For more info: http://johanleino.wordpress.com/2013/09/13/pester-unit-testing-for-powershell/

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$suit = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".psm1")

$module= $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\$suit")
$code = Get-Content $module | Out-String
Invoke-Expression $code

$sharedHelper = $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\shared.ps1")
. $sharedHelper

Describe "#Get-Settings-File" {

  In $TestDrive {
    $configRootPath = ".\Packages\Plugin\ChefExtensionHandler\RuntimeSettings"
    Setup -Dir $configRootPath
    mock Chef-GetExtensionRoot { return $configRootPath }
  
    It "finds no config file and so exits with error message" {
      $configFile = ""
      Get-Settings-File | should Be("[$(Get-Date)] No config file found !!")
    }
  
    It "returns runtime config/settings file path" {
	  $configFile = "$configRootPath\0.settings"
	  Setup -File $configFile
      $configFilePath = Get-Settings-File
      $configFilePath | should Match($configFile)
      Remove-Item $configFile
    }
    Assert-MockCalled Chef-GetExtensionRoot -Times 1
    Assert-VerifiableMocks
	Remove-Item $configRootPath
  }
}

Describe "#Get-Chef-Version" {

  In $TestDrive {
  
    $settingsFile = ".\Packages\Plugin\ChefExtensionHandler\RuntimeSettings\0.settings"
    Setup -File $settingsFile
	mock Get-Settings-File { return $settingsFile }
	
    It "returns empty string" {
      $config_data = '{"runtimeSettings":[{"handlerSettings":{"protectedSettingsCertThumbprint":"some_thumbprint","protectedSettings":"some_key","publicSettings":{"client_rb":"chef_server_url \t \"https://api.opscode.com/organizations/some_org\"\nvalidation_client_name\t\"some_org-validator\"","runlist":"","autoUpdateClient":"false","deleteChefConfig":"false","custom_json_attr":{},"bootstrap_options":{"chef_server_url":"https://api.opscode.com/organizations/some_org","validation_client_name":"some_org-validator"}}}}]}'
      $config_data | Set-Content $settingsFile
      $chefVersion = Get-Chef-Version
      $chefVersion | should Match("")
      Remove-Item $settingsFile
    }
  
    It "returns chef-version to be installed" {
      $config_data = '{"runtimeSettings":[{"handlerSettings":{"protectedSettingsCertThumbprint":"some_thumbprint","protectedSettings":"some_key","publicSettings":{"client_rb":"chef_server_url \t \"https://api.opscode.com/organizations/some_org\"\nvalidation_client_name\t\"some_org-validator\"","runlist":"","autoUpdateClient":"false","deleteChefConfig":"false","custom_json_attr":{},"bootstrap_options":{"chef_server_url":"https://api.opscode.com/organizations/some_org","validation_client_name":"some_org-validator","bootstrap_version":"12.3.2"}}}}]}'
      $config_data | Set-Content $settingsFile
      $chefVersion = Get-Chef-Version
      $chefVersion | should Match("12.3.2")
      Remove-Item $settingsFile
    }
	Assert-MockCalled Get-Settings-File -Times 1
	Assert-VerifiableMocks
  }
}

describe "#Install-ChefClient" {
  it "install chef and azure chef extension gem successfully" {
    # create temp powershell file for mock Get-SharedHelper
    $tempPS = ([System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru)
    mock Get-SharedHelper {return $tempPS}

    $extensionRoot = "C:\Packages\Plugin\ChefExtensionHandler"
    mock Chef-GetExtensionRoot {return $extensionRoot}

    mock Download-ChefClient

    $env:temp = "C:\AppData\Temp"
    $localMsiPath = "$env:temp\\chef-client-latest.msi"
    mock Get-LocalDestinationMsiPath {return $localMsiPath}

    $chefMsiLogPath = $env:tmp
    mock Get-ChefClientMsiLogPath {return $chefMsiLogPath}

    mock Archive-ChefClientLog

    mock Run-ChefInstaller

    mock Install-AzureChefExtensionGem

    Install-ChefClient

    # Delete temp file created for Get-SharedHelper
    Remove-Item $tempPS

    # Download-ChefClient should called atleast 1 time
    Assert-MockCalled Download-ChefClient -Times 1

    # Archive-ChefClientLog should called with $chefMsiLogPath params atleast 1 time
    Assert-MockCalled Archive-ChefClientLog -Times 1 -ParameterFilter{$chefClientMsiLogPath -eq $chefMsiLogPath}

    Assert-MockCalled Get-LocalDestinationMsiPath -Times 1

    Assert-MockCalled Run-ChefInstaller -Times 1 -ParameterFilter{$localDestinationMsiPath -eq $localMsiPath -and $chefClientMsiLogPath -eq $chefMsiLogPath}

    Assert-MockCalled Install-AzureChefExtensionGem -Times 1 -ParameterFilter{$chefExtensionRoot -eq $extensionRoot}

    Assert-VerifiableMocks
  }

  context "when chefClientMsiLogPath not exist" {
    it "install chef client, azure chef extension gem and skip chef log archiving" {
      mock Get-SharedHelper {return "C:"}
      mock Chef-GetExtensionRoot -Verifiable
      mock Get-LocalDestinationMsiPath -Verifiable
      $chefMsiLogPath = "C:\invalid"
      mock Get-ChefClientMsiLogPath {return $chefMsiLogPath} -Verifiable
      mock Run-ChefInstaller -Verifiable
      mock Install-AzureChefExtensionGem -Verifiable
      mock Archive-ChefClientLog

      Install-ChefClient

      Assert-MockCalled Archive-ChefClientLog -Times 0 -ParameterFilter{$chefClientMsiLogPath -eq $chefMsiLogPath}
      Assert-VerifiableMocks
    }
  }
}

describe "#Get-SharedHelper" {
  it "returns shared helper" {
    $extensionRoot = "C:\Users\azure\azure-chef-extension\ChefExtensionHandler"
    mock Chef-GetExtensionRoot {return $extensionRoot} -Verifiable
    $result = Get-SharedHelper

    $result | should Be("$extensionRoot\\bin\\shared.ps1")
    Assert-VerifiableMocks
  }
}

describe "#Get-LocalDestinationMsiPath" {
  it "contains chef-client-latest.msi path" {
    $env:temp = "C:\AppData\Temp"
    $result = Get-LocalDestinationMsiPath
    $result | should Match("\\chef-client-latest.msi")
  }
}

describe "#Get-ChefClientMsiLogPath" {
  it "returns chef-client msi log path" {
    $result = Get-ChefClientMsiLogPath
    $env:temp = "C:\AppData\Temp"
    $result | should Match("\\chef-client-msi806.log")
  }
}
