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

# Pester 5 only executes file-scope code during Discovery, not Run — compute
# paths and dot-source/import inside BeforeAll so the functions under test
# are available when It blocks execute.
BeforeAll {
  $here = Split-Path -Parent $PSCommandPath
  $suit = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.ps1", ".psm1")

  $module= $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\$suit")
  # Load the .psm1 content into this scope (rather than Import-Module) so
  # Pester's Mock can intercept calls to its functions directly. Dot-source
  # from a real temp .ps1 file (not Invoke-Expression) so Chef-GetScriptDirectory's
  # $MyInvocation.MyCommand.Path lookup resolves to a real path instead of $null.
  $code = Get-Content $module | Out-String
  $tempModuleScript = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.ps1'
  Set-Content -Path $tempModuleScript -Value $code
  # Export-ModuleMember only works inside a real module; no-op it since we're
  # intentionally loading into this scope directly (for Pester mocking) rather
  # than via Import-Module.
  function Export-ModuleMember { }
  . $tempModuleScript
  Remove-Item $tempModuleScript

  $sharedHelper = $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\shared.ps1")
  . $sharedHelper
}

describe "#Install-ChefClient" {
  BeforeEach {
    # create temp powershell file for mock Get-SharedHelper
    $script:tempPS = ([System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru)
    mock Get-SharedHelper {return $script:tempPS}
    mock Get-PowershellVersion { return 3 }
    mock Get-PublicSettings-From-Config-Json { return $null }
    mock Get-ChefPackage { return $null }
    mock Get-ChefLicenseKey { return $null }
    mock Get-ChefLicenseBypass { return "true" }
    mock Write-LicenseKeyStatus
    mock Chef-GetExtensionRoot { return "C:\Packages\Plugin\ChefExtensionHandler" }
    mock Install-AzureChefExtensionGem
  }

  AfterEach {
    Remove-Item $script:tempPS -ErrorAction SilentlyContinue
  }

  context "when a local chef_package_path is configured" {
    it "installs from the local msi and skips downloading" {
      mock Get-PublicSettings-From-Config-Json { return "C:\temp\chef-client.msi" } -ParameterFilter { $key -eq "chef_package_path" }
      mock Get-PublicSettings-From-Config-Json { return $null } -ParameterFilter { $key -eq "chef_package_url" }
      mock Get-PublicSettings-From-Config-Json { return "service" } -ParameterFilter { $key -eq "daemon" }
      mock Install-ChefMsi

      Install-ChefClient

      Assert-MockCalled Install-ChefMsi -Times 1 -ParameterFilter { $msi -eq "C:\temp\chef-client.msi" -and $addlocal -eq "service" }
      Assert-MockCalled Install-AzureChefExtensionGem -Times 1 -ParameterFilter { $chefExtensionRoot -eq "C:\Packages\Plugin\ChefExtensionHandler" }
    }
  }

  context "when a chef_package_url is configured" {
    it "downloads the msi and installs it" {
      mock Get-PublicSettings-From-Config-Json { return $null } -ParameterFilter { $key -eq "chef_package_path" }
      mock Get-PublicSettings-From-Config-Json { return "https://example.test/chef-client.msi" } -ParameterFilter { $key -eq "chef_package_url" }
      mock Get-PublicSettings-From-Config-Json { return "task" } -ParameterFilter { $key -eq "daemon" }
      mock Invoke-WebRequest
      mock Install-ChefMsi

      Install-ChefClient

      Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -eq "https://example.test/chef-client.msi" }
      Assert-MockCalled Install-ChefMsi -Times 1 -ParameterFilter { $addlocal -eq "task" }
    }
  }

  context "when chef_license_key is set in config" {
    it "sets CHEF_LICENSE_KEY environment variable during install" {
      mock Get-PublicSettings-From-Config-Json { return "C:\temp\chef-client.msi" } -ParameterFilter { $key -eq "chef_package_path" }
      mock Get-PublicSettings-From-Config-Json { return $null } -ParameterFilter { $key -eq "chef_package_url" }
      mock Get-PublicSettings-From-Config-Json { return "service" } -ParameterFilter { $key -eq "daemon" }
      mock Install-ChefMsi
      mock Get-ChefLicenseKey { return "test-key-xyz" }
      mock Set-ChefLicenseKeyEnv

      Install-ChefClient

      Assert-MockCalled Set-ChefLicenseKeyEnv -Times 1 -ParameterFilter { $licenseKey -eq "test-key-xyz" }
    }
  }
}

describe "#Get-SharedHelper" {
  it "returns shared helper" {
    $extensionRoot = "C:\Users\azure\azure-chef-extension\ChefExtensionHandler"
    mock Chef-GetExtensionRoot {return $extensionRoot} -Verifiable
    $result = Get-SharedHelper

    $result | Should -Be "$extensionRoot\\bin\\shared.ps1"
    Should -InvokeVerifiable
  }
}
