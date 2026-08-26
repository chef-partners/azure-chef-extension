source "https://rubygems.org"

# ponytail: azure-chef-extension ships no runtime gem dependencies -- Chef is
# installed as an OS package on target nodes, not bundled (see gemspec). This
# Gemfile/Gemfile.lock is what BlackDuck SCA scans, so it stays empty rather
# than pulling in chef/rspec/rubocop/etc. and generating BOM noise for gems
# that are never shipped. All dev/test/lint tooling lives in
# gemfiles/test.gemfile -- run it with:
#   BUNDLE_GEMFILE=gemfiles/test.gemfile bundle exec rspec ...
