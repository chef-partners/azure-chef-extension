
# To create a zip file for publishing handler?

# To run tests (rspec)?

# May be task to publish the release-version of zip to azure using azure apis (release automation)

require 'rake/packagetask'

PACKAGE_NAME = "ChefExtensionHandler"
VERSION = "1.0"
CHEF_BUILD_DIR = "pkg"

task :build do
  puts "Building Chef Package..."
  puts %x{powershell "scripts\\createzip.ps1 #{CHEF_BUILD_DIR} #{PACKAGE_NAME}_#{VERSION}.zip #{PACKAGE_NAME}"}
end

task :clean do
  puts %x{ powershell -Command if (Test-Path "#{CHEF_BUILD_DIR}") { Remove-Item -Recurse -Force "#{CHEF_BUILD_DIR}"}}
end

task :spec do
  puts "Running spec..."
  puts %x{powershell -Command if (Test-Path "../Pester") {Remove-Item -Recurse -Force ../Pester"}}
  puts %x{powershell "git clone https://github.com/muktaa/Pester ../Pester"}
  puts %x{powershell Import-Module ../Pester/Pester.psm1}
end