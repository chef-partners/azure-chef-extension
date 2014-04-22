#
# To run pester tests you have to clone git-repo: $git clone https://github.com/pester/Pester
# Then open powershell terminal and do:
# To import pester
# PS>Import-Module <pester_git_repo_path>/Pester.psm1
#
# To run pester tests
# PS>Invoke-Pester -relative_path <azure-chef-extension-repo-path>/spec/chef-uninstall.Tests.ps1
#
# For more info: http://johanleino.wordpress.com/2013/09/13/pester-unit-testing-for-powershell/

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".psm1")

$module= $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\$sut")
$code = Get-Content $module | Out-String
Invoke-Expression $code

$sharedHelper = $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\shared.ps1")
. $sharedHelper

describe "#Uninstall-ChefClientPackage" {
  context "when configuration directory exist" {
    it "uninstall chef package and remove configuration directory" {
      $chef_pkg = New-Module {
        function Uninstall {}
      } -asCustomObject

      mock Remove-Item
      mock Get-BootstrapDirectory { return $env:tmp}
      mock Get-ChefInstallDirectory { return $env:tmp }
      mock Get-ChefPackage { return $chef_pkg }

      Uninstall-ChefClientPackage

      Assert-MockCalled Remove-Item -Times 2
      Assert-MockCalled Get-ChefPackage -Times 1
    }
  }

  context "when configuration directory not exist" {
    it "uninstall chef package and don't try to remove non existent configuration directory" {
      $chef_pkg = New-Module {
        function Uninstall {}
      } -asCustomObject

      mock Remove-Item
      mock Get-BootstrapDirectory { return "$($env:tmp)\\invalid"}
      mock Get-ChefInstallDirectory { return "$($env:tmp)\\invalid" }
      mock Get-ChefPackage { return $chef_pkg }

      Uninstall-ChefClientPackage

      Assert-MockCalled Remove-Item -Times 0
    }
  }
}

describe "#Uninstall-ChefClient" {
  context "when powershell version 3" {
    it "uninstall chef and azure-chef-extension gem successfully" {
      # create temp powershell file for mock Get-SharedHelper
      $tempPS = ([System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru)
      mock Get-SharedHelper {return $tempPS}
      mock Read-JsonFile
      mock Write-ChefStatus
      mock Uninstall-ChefService
      mock Uninstall-AzureChefExtensionGem
      mock Uninstall-ChefClientPackage
      mock Get-PowershellVersion { return 3 }
      mock Test-ChefExtensionRegistry { return $false }

      Uninstall-ChefClient
      # Delete temp file created for Get-SharedHelper
      Remove-Item $tempPS
      Assert-MockCalled Write-ChefStatus -Times 2
      Assert-MockCalled Read-JsonFile -Times 1
      Assert-MockCalled Uninstall-ChefService -Times 1
      Assert-MockCalled Uninstall-AzureChefExtensionGem -Times 1
      Assert-MockCalled Uninstall-ChefClientPackage -Times 1
    }
  }

  context "when powershell version 2" {
    it "uninstall chef and azure-chef-extension gem successfully" {
      # create temp powershell file for mock Get-SharedHelper
      $tempPS = ([System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru)
      mock Get-SharedHelper {return $tempPS}
      mock Read-JsonFile
      mock Write-ChefStatus
      mock Uninstall-ChefService
      mock Uninstall-AzureChefExtensionGem
      mock Uninstall-ChefClientPackage
      mock Get-PowershellVersion { return 2 }
      mock Test-ChefExtensionRegistry { return $false }

      Uninstall-ChefClient
      # Delete temp file created for Get-SharedHelper
      Remove-Item $tempPS
      Assert-MockCalled Write-ChefStatus -Times 0
      Assert-MockCalled Read-JsonFile -Times 0

      Assert-MockCalled Uninstall-ChefService -Times 1
      Assert-MockCalled Uninstall-AzureChefExtensionGem -Times 1
      Assert-MockCalled Uninstall-ChefClientPackage -Times 1
    }
  }


  context "when update process is running" {
    it "skip chef uninstallation" {
      # # create temp powershell file for mock Get-SharedHelper
      $tempPS = ([System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru)
      mock Get-SharedHelper {return $tempPS}
      mock Read-JsonFile
      mock Write-ChefStatus
      mock Uninstall-ChefService
      mock Uninstall-AzureChefExtensionGem
      mock Uninstall-ChefClientPackage
      mock Update-ChefExtensionRegistry
      mock Get-PowershellVersion { return 3 }
      mock Test-ChefExtensionRegistry { return $true }

      Uninstall-ChefClient
      # Delete temp file created for Get-SharedHelper
      Remove-Item $tempPS
      Assert-MockCalled Update-ChefExtensionRegistry -Times 1
      Assert-MockCalled Write-ChefStatus -Times 1
      Assert-MockCalled Read-JsonFile -Times 1
      Assert-MockCalled Uninstall-ChefService -Times 0
      Assert-MockCalled Uninstall-AzureChefExtensionGem -Times 0
      Assert-MockCalled Uninstall-ChefClientPackage -Times 0
    }
  }
}
