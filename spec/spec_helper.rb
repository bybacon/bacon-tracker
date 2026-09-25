require 'rake'
require 'bacon_tracker'
require 'bacon_tracker/tasks'
require 'bacon_tracker/launcher'
require 'tmpdir'
require 'fileutils'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Never launch a real editor or file manager from the suite - the reveal and
  # editor specs used to pop Finder windows on macOS and pass on Linux only
  # because the spawn failure was swallowed. Pin the platform too, so the
  # argv a spec expects is the same on every CI runner.
  config.before do
    allow(BaconTracker::Launcher).to receive(:run)
    allow(BaconTracker::Launcher).to receive(:host_os).and_return('darwin')
  end
end

def silence_output(&block)
  original = $stdout
  $stdout = StringIO.new
  block.call
ensure
  $stdout = original
end

def silence_errors(&block)
  original = $stderr
  $stderr = StringIO.new
  block.call
ensure
  $stderr = original
end

# Build a minimal docs-repo fixture in a tmpdir and yield a configured Core.
def with_fixture_repo(namespace: 'TST', decisions: false)
  Dir.mktmpdir do |root|
    %w[features bugs chores].each do |kind|
      ext = kind == 'features' ? '.feature' : '.md'
      %w[1_icebox 2_backlog 3_started 4_done].each { |s| FileUtils.mkdir_p("#{root}/#{kind}/#{s}") }

      if kind == 'features'
        File.write("#{root}/#{kind}/_template.feature",
                   "Feature: Name the Feature\n  Scenario: placeholder\n")
      else
        File.write("#{root}/#{kind}/_template.md",
                   "Title: placeholder\n\nDescription here.\n")
      end
    end

    File.write("#{root}/.next-id", '1')
    File.write("#{root}/backlog.md", '')

    config = BaconTracker::Configuration.new
    config.namespace = namespace
    config.tracker_root = root

    # The decisions tree is opt-in: most specs do not need it, and building it
    # unconditionally would change `root`'s shape for every existing example.
    if decisions
      decisions_root = File.join(root, 'docs', 'decisions')
      BaconTracker::STATUSES.each { |st| FileUtils.mkdir_p(File.join(decisions_root, st)) }
      File.write(File.join(decisions_root, '_template.md'),
                 "---\nstatus: proposed\ndate: YYYY-MM-DD\n---\n\n# Name the decision\n")
      File.write(File.join(decisions_root, '.next-id'), '1')
      File.write(File.join(decisions_root, 'proposed.md'), "# Decisions to make, in order\n")
      config.decisions_root = decisions_root
    end

    yield BaconTracker::Core.new(config), root
  end
end

# Write one ADR into a fixture's decisions tree and return its path. Frontmatter
# is passed through verbatim so a spec can build an invalid record on purpose -
# the lint's whole job is catching those.
def write_decision(core, status:, id:, slug: 'a-decision', frontmatter: nil, body: nil)
  fm = frontmatter || "---\nstatus: #{status}\ndate: 2026-09-14\n---\n"
  name = "#{core.config.namespace}-ADR-#{format('%04d', id)}-#{slug}.md"
  path = File.join(core.config.decisions_root, status, name)
  File.write(path, "#{fm}\n# #{slug.tr('-', ' ').capitalize}\n\n#{body || 'Context here.'}\n")
  # Keep the fixture's counter consistent with what was just written - a helper
  # that plants a record but leaves .next-id stale hands every caller a lint
  # failure it didn't ask for.
  counter = core.config.decisions_next_id_path
  File.write(counter, (id + 1).to_s) if File.read(counter).strip.to_i <= id
  path
end
