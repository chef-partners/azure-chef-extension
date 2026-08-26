module ChefAzure
  # ponytail: single source of truth is the repo-root VERSION file (also
  # used for Azure extension releases and BlackDuck scan reporting); this
  # used to be a separately hand-maintained "0.0.1" that never matched.
  VERSION = File.read(File.expand_path("../../../VERSION", __FILE__)).strip
  MAJOR, MINOR, TINY = VERSION.split('.')
end
