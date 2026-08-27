source "https://rubygems.org"

# Specify your gem's dependencies in azure-chef-extension.gemspec
gemspec

# ponytail: this Gemfile.lock is what BlackDuck SCA scans, and we want it to
# reflect the real dev/test dependency graph (chef, rspec, rubocop, etc.), so
# it's a plain copy of gemfiles/test.gemfile rather than a pared-down,
# runtime-only Gemfile. Keep the two in sync when either changes; split them
# again if that becomes a real maintenance burden.

# Chef is only a dev/test dependency (used by the spec suite to stub
# Chef::Handler/Chef::Log/etc.) -- the extension itself installs Chef as an
# OS package on target nodes, not as a gem. Chef >= 18 requires Ruby >= 3.1,
# so pick the newest Chef series that supports whichever Ruby is currently
# running. This lets CI exercise Ruby 2.7.x and the RHEL 9 / RHEL 10 default
# Rubies (3.0.x / 3.3.x) with a single Gemfile.
gem "chef", (RUBY_VERSION >= "3.1" ? "~> 18.0" : "~> 17.0")

# public_suffix and faraday-http-cache (pulled in transitively, likely via
# chef's HTTP/vendor gems) release newer major versions that drop support
# for older Rubies (e.g. public_suffix 7.x and faraday-http-cache 2.7+
# require Ruby >= 3.2); pin both to versions that still work across our
# whole Ruby test matrix (2.7 - 3.3).
gem "public_suffix", "~> 5.1"
gem "faraday-http-cache", "~> 2.5.1"
gem "multi_json", "~> 1.15.0"

group :development do
  gem "pry"
  gem "rb-readline"
  gem "rake"
  # ponytail: was pinned to the exact patch "~> 2.1.4", which has no further
  # 2.1.x releases -- Dependabot's forced security update can't find any
  # version to move to within that constraint and crashes. "~> 2.2" still
  # satisfies chef-zero's "rack (~> 2.0, >= 2.0.6)" and Ruby 2.7+, but lets
  # Dependabot bump patch releases going forward.
  gem "rack", "~> 2.2"
end
