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
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".psm1")

$module= $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\$sut")
$code = Get-Content $module | Out-String
Invoke-Expression $code

$sharedHelper = $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\shared.ps1")
. $sharedHelper

describe "#Install-ChefClient" {
  it "install chef and azure chef extension gem successfully" {
    # create temp powershell file for mock Get-SharedHelper
    $tempPS = ([System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru)
    mock Get-SharedHelper {return $tempPS}

    $extensionRoot = "C:\Packages\Plugin\ChefExtensionHandler"
    mock Chef-GetExtensionRoot {return $extensionRoot}

    $localMsiPath = "C:\Packages\Plugin\ChefExtensionHandler\installer\chef-client-latest.msi"
    mock Get-LocalDestinationMsiPath {return $localMsiPath}

    $chefMsiLogPath = $env:tmp
    mock Get-ChefClientMsiLogPath {return $chefMsiLogPath}

    mock Archive-ChefClientLog

    mock Run-ChefInstaller

    mock Install-AzureChefExtensionGem

    mock Chef-AddToPath -Verifiable

    Install-ChefClient

    # Delete temp file created for Get-SharedHelper
    Remove-Item $tempPS

    # Archive-ChefClientLog should called with $chefMsiLogPath params atleast 1 time
    Assert-MockCalled Archive-ChefClientLog -Times 1 -ParameterFilter{$chefClientMsiLogPath -eq $chefMsiLogPath}

    Assert-MockCalled Get-LocalDestinationMsiPath -Times 1 -ParameterFilter{$chefExtensionRoot -eq $extensionRoot}

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
      mock Chef-AddToPath -Verifiable

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
    $extensionRoot = "C:\Users\azure\azure-chef-extension\ChefExtensionHandler"
    $result = Get-LocalDestinationMsiPath($extensionRoot)

    $result | should Match("\\installer\\chef-client-latest.msi")
  }
}

describe "#Get-ChefClientMsiLogPath" {
  it "returns chef-client msi log path" {
    $result = Get-ChefClientMsiLogPath
    $env:temp = "C:\AppData\Temp"
    $result | should Match("\\chef-client-msi806.log")
  }
}
