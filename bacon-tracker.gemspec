require_relative 'lib/bacon_tracker/version'

Gem::Specification.new do |s|
  s.name          = "bacon-tracker"
  s.version       = BaconTracker::VERSION
  s.summary       = "A project tracker that lives in your repo as plain files"
  s.description   = "Stories, bugs, chores and decision records as Markdown and Gherkin files in your git repo, " \
                    "driven from Rake, a local web board, or Claude Code. No database, no service."
  s.authors       = ["Alex Berger"]
  s.email         = ["alex@aberger.me"]
  s.homepage      = "https://github.com/bybacon/bacon-tracker"
  s.files         = Dir["lib/**/*.{rb,md,js,erb}"] + Dir["bin/*"] +
                    ["LICENSE", "README.md", "CHANGELOG.md"]
  s.executables   = ["tracker-dashboard", "tracker-init"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.3"

  s.license = "MIT"

  s.metadata = {
    "homepage_uri"          => s.homepage,
    "changelog_uri"         => "https://github.com/bybacon/bacon-tracker/blob/main/CHANGELOG.md",
    "bug_tracker_uri"       => "https://github.com/bybacon/bacon-tracker/issues",
    "rubygems_mfa_required" => "true"
  }

  # rake is the primary interface (lib/bacon_tracker/tasks.rb extends Rake::DSL
  # at load) - a runtime dependency, not just a dev one (BT-092). Bounded like
  # puma: floor = the major in use, ceiling = one major of headroom. An
  # open-ended requirement makes `gem build` warn, which fails CI.
  s.add_dependency "rake", ">= 13.0", "< 15"
  # `bundle outdated` permanently reports mustermann one major behind: sinatra
  # 4.x caps it at `~> 3.0`, so mustermann 4 is unreachable until sinatra 5
  # ships. Expected, not neglect - nothing to do about it here.
  # 4.1 is the floor: host_authorization (the DNS-rebinding guard in server.rb)
  # does not exist in 4.0, where setting it is a silent no-op.
  s.add_dependency "sinatra", "~> 4.1"
  s.add_dependency "rackup",  "~> 2.0"
  s.add_dependency "puma",    ">= 7.2.1", "< 9"
  # Markdown for the docs surface - pure Ruby, no native build step, GFM for
  # task lists and tables (BT-ADR-0018).
  s.add_dependency "kramdown",            "~> 2.4"
  s.add_dependency "kramdown-parser-gfm", "~> 1.1"

  # Same story for diff-lcs: rspec-expectations caps it below 2.0, and rspec
  # has been on 3.x since 2014 - treat diff-lcs 1.x as permanent.
  s.add_development_dependency "rspec", "~> 3.13"
  # Tilt prefers erubi over stdlib ERB when present, and most user machines
  # have it - run the specs against the engine users actually get.
  s.add_development_dependency "erubi", "~> 1.13"
  s.add_development_dependency "rack-test", "~> 2.2"
end
