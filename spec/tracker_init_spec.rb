require 'spec_helper'
require 'open3'

RSpec.describe 'tracker-init' do
  let(:gem_root) { File.expand_path('..', __dir__) }
  let(:bundled_command) { File.join(gem_root, 'lib', 'bacon_tracker', 'commands', 'tracker.md') }

  def run_init(root, command: false)
    args = [
      RbConfig.ruby, "-I#{gem_root}/lib", File.join(gem_root, 'bin', 'tracker-init'),
      '--path', File.join(root, 'proj'),
      '--namespace', 'TST',
      '--title', 'Test Project',
      '--dashboard', File.join(root, 'dashboard.md'),
      '--yes'
    ]
    args << '--command' if command
    Open3.capture3(*args)
  end

  it 'installs the /tracker command next to dashboard.md when --command is passed' do
    Dir.mktmpdir do |root|
      _out, err, status = run_init(root, command: true)

      expect(status).to be_success, err
      installed = File.join(root, '.claude', 'commands', 'tracker.md')
      expect(File.exist?(installed)).to be(true)
      expect(File.read(installed)).to eq(File.read(bundled_command))
    end
  end

  it 'skips the /tracker command unless --command is passed' do
    Dir.mktmpdir do |root|
      _out, err, status = run_init(root)

      expect(status).to be_success, err
      installed = File.join(root, '.claude', 'commands', 'tracker.md')
      expect(File.exist?(installed)).to be(false)
    end
  end

  it 'does not overwrite an existing tracker command' do
    Dir.mktmpdir do |root|
      installed = File.join(root, '.claude', 'commands', 'tracker.md')
      FileUtils.mkdir_p(File.dirname(installed))
      File.write(installed, "user edits\n")

      _out, err, status = run_init(root, command: true)

      expect(status).to be_success, err
      expect(File.read(installed)).to eq("user edits\n")
    end
  end

  it 'generates a Rakefile pointing at the chosen dashboard filename (BT-059)' do
    Dir.mktmpdir do |root|
      _out, err, status = Open3.capture3(
        RbConfig.ruby, "-I#{gem_root}/lib", File.join(gem_root, 'bin', 'tracker-init'),
        '--path', File.join(root, 'proj'),
        '--namespace', 'TST',
        '--title', 'Test Project',
        '--dashboard', File.join(root, 'board.md'),
        '--yes'
      )
      expect(status).to be_success, err
      rakefile = File.read(File.join(root, 'Rakefile'))
      expect(rakefile).to include("'board.md'")
      expect(rakefile).not_to include("'dashboard.md'")
    end
  end

  it 'registers a namespace that is a prefix of an existing one (BT-063)' do
    Dir.mktmpdir do |root|
      dash = File.join(root, 'dashboard.md')
      File.write(dash, "# Bacon Dashboard\n\n## Existing\npath: #{root}/existing/tracker\nnamespace: BCN\n")
      _out, err, status = Open3.capture3(
        RbConfig.ruby, "-I#{gem_root}/lib", File.join(gem_root, 'bin', 'tracker-init'),
        '--path', File.join(root, 'proj'),
        '--namespace', 'BC',
        '--title', 'Prefix Project',
        '--dashboard', dash,
        '--yes'
      )
      expect(status).to be_success, err
      expect(File.read(dash)).to include("namespace: BC\n")
    end
  end

  it 'ships the command file in the gemspec file list' do
    gemspec = Gem::Specification.load(File.join(gem_root, 'bacon-tracker.gemspec'))
    expect(gemspec.files).to include('lib/bacon_tracker/commands/tracker.md')
  end

  # docs/ stays on GitHub - it holds the project's own tracker and ADRs, and the
  # README links there absolutely, so nothing in the gem points at a missing file.
  it 'ships README and CHANGELOG but not docs, and sets metadata URIs (BT-090)' do
    gemspec = Gem::Specification.load(File.join(gem_root, 'bacon-tracker.gemspec'))
    expect(gemspec.files).to include('README.md', 'CHANGELOG.md')
    expect(gemspec.files.grep(%r{\Adocs/})).to be_empty
    expect(gemspec.metadata).to include(
      'homepage_uri', 'changelog_uri', 'bug_tracker_uri', 'rubygems_mfa_required'
    )
  end

  it 'declares rake as a runtime dependency, not just development (BT-092)' do
    gemspec = Gem::Specification.load(File.join(gem_root, 'bacon-tracker.gemspec'))
    runtime = gemspec.dependencies.select { |d| d.type == :runtime }.map(&:name)
    expect(runtime).to include('rake')
  end

  it 'aborts on a namespace already registered, creating nothing new (BT-109)' do
    Dir.mktmpdir do |root|
      _o, e1, s1 = run_init(root)
      expect(s1).to be_success, e1

      # second project, different path, same namespace TST
      _o2, err2, s2 = Open3.capture3(
        RbConfig.ruby, "-I#{gem_root}/lib", File.join(gem_root, 'bin', 'tracker-init'),
        '--path', File.join(root, 'proj2'),
        '--namespace', 'TST',
        '--title', 'Two',
        '--dashboard', File.join(root, 'dashboard.md'),
        '--yes'
      )
      expect(s2).not_to be_success
      expect(err2).to match(/already registered/i)
      expect(Dir.exist?(File.join(root, 'proj2', 'tracker'))).to be(false) # nothing created
    end
  end

  it "cancels (exit 0, nothing created) when the confirm prompt is answered 'no' (BT-111)" do
    Dir.mktmpdir do |root|
      out, _e, status = Open3.capture3(
        RbConfig.ruby, "-I#{gem_root}/lib", File.join(gem_root, 'bin', 'tracker-init'),
        '--path', File.join(root, 'proj'),
        '--namespace', 'TST',
        '--title', 'Test Project',
        '--dashboard', File.join(root, 'dashboard.md'),
        stdin_data: "no\n"
      )
      expect(status).to be_success
      expect(out).to match(/Cancelled/)
      expect(Dir.exist?(File.join(root, 'proj', 'tracker'))).to be(false)
    end
  end

  it 'aborts (creating nothing) when the namespace is shorter than 2 characters (BT-096)' do
    Dir.mktmpdir do |root|
      _o, err, status = Open3.capture3(
        RbConfig.ruby, "-I#{gem_root}/lib", File.join(gem_root, 'bin', 'tracker-init'),
        '--path', File.join(root, 'proj'),
        '--namespace', 'X',
        '--title', 'Test Project',
        '--dashboard', File.join(root, 'dashboard.md'),
        '--yes'
      )
      expect(status).not_to be_success
      expect(err).to match(/2-8 characters/i)
      expect(Dir.exist?(File.join(root, 'proj', 'tracker'))).to be(false)
    end
  end
end

RSpec.describe 'tracker-init decisions scaffolding (BT-157)' do
  include_context 'tracker-init' rescue nil

  def gem_root = File.expand_path('..', __dir__)

  def run_init(root)
    Open3.capture3(RbConfig.ruby, "-I#{gem_root}/lib",
                   File.join(gem_root, 'bin', 'tracker-init'),
                   '--path', File.join(root, 'proj'), '--namespace', 'TST',
                   '--title', 'Test Project',
                   '--dashboard', File.join(root, 'dashboard.md'), '--yes')
  end

  it 'creates the five status directories, the template, .next-id and proposed.md' do
    Dir.mktmpdir do |dir|
      run_init(dir)
      d = File.join(dir, 'proj', 'docs', 'decisions')

      BaconTracker::STATUSES.each { |s| expect(Dir.exist?(File.join(d, s))).to be(true) }
      expect(File.read(File.join(d, '.next-id'))).to eq('1')
      expect(File.read(File.join(d, '_template.md'))).to include('status: proposed')
      expect(File.read(File.join(d, 'proposed.md'))).to include('Decisions to make')
    end
  end
end

RSpec.describe 'tracker-init setup, end to end (BT-179)' do
  def gem_root = File.expand_path('..', __dir__)

  def init(root, *extra, stdin: '')
    Open3.capture3(RbConfig.ruby, "-I#{gem_root}/lib", File.join(gem_root, 'bin', 'tracker-init'),
                   '--path', File.join(root, 'proj'), *extra, chdir: root, stdin_data: stdin)
  end

  it 'runs with --yes and no --dashboard without reading stdin' do
    Dir.mktmpdir do |root|
      # A closed stdin would make any prompt fall back or fail - the point is
      # that nothing asks: the dashboard lands in the working directory.
      _o, err, status = init(root, '--namespace', 'APP', '--yes')
      expect(status).to be_success, err
      expect(File.read(File.join(root, 'dashboard.md'))).to include("namespace: APP\n")
    end
  end

  it 'fails fast under --yes when a required flag is missing' do
    Dir.mktmpdir do |root|
      _o, err, status = init(root, '--yes')
      expect(status).not_to be_success
      expect(err).to match(/Namespace.*required.*--yes/)
    end
  end

  it 'accepts digits in a namespace and refuses rather than rewrites a bad one' do
    Dir.mktmpdir do |root|
      _o, err, status = init(root, '--namespace', 'b2b', '--yes')
      expect(status).to be_success, err
      expect(File.read(File.join(root, 'dashboard.md'))).to include("namespace: B2B\n")

      _o, err, status = init(root, '--namespace', 'my-app', '--yes', '--dashboard', File.join(root, 'other.md'))
      expect(status).not_to be_success
      expect(err).to match(/2-8 characters/)
    end
  end

  it 'registers the project directory and git-ignores both lock files' do
    Dir.mktmpdir do |root|
      _o, err, status = init(root, '--namespace', 'APP', '--yes')
      expect(status).to be_success, err
      expect(File.read(File.join(root, 'dashboard.md'))).to include("path: #{File.realpath(root)}/proj\n").or include("path: #{root}/proj\n")
      expect(File.read(File.join(root, 'proj', 'tracker', '.gitignore'))).to eq(".lock\n")
      expect(File.read(File.join(root, 'proj', 'docs', 'decisions', '.gitignore'))).to eq(".lock\n")
    end
  end

  # The recommended setup, exactly as the README runs it: init, then rake from
  # the dashboard home. The stories must land where the board reads them.
  it 'writes rake-created stories and decisions where the board reads them' do
    Dir.mktmpdir do |root|
      _o, err, status = init(root, '--namespace', 'APP', '--yes')
      expect(status).to be_success, err

      rake = ->(*args) { Open3.capture3({ 'NS' => 'APP' }, RbConfig.ruby, "-I#{gem_root}/lib", '-S', 'rake', *args, chdir: root) }
      out, err, status = rake.call('story:feature[First story]')
      expect(status).to be_success, err + out
      out, err, status = rake.call('decision:new[Use files]')
      expect(status).to be_success, err + out

      proj = File.join(root, 'proj')
      expect(Dir.glob("#{proj}/tracker/features/1_icebox/APP-001-*.feature").size).to eq(1)
      expect(Dir.glob("#{proj}/docs/decisions/proposed/APP-ADR-0001-*.md").size).to eq(1)
      # Nothing leaked beside tracker/ - the BT-179 failure wrote here.
      expect(Dir.exist?(File.join(proj, 'features'))).to be(false)
      expect(File.exist?(File.join(proj, '.next-id'))).to be(false)

      require 'bacon_tracker/dashboard'
      stats = BaconTracker::Dashboard.new(File.join(root, 'dashboard.md')).project_stats.first
      expect(stats).to include(icebox: 1, decisions: 1, proposed: 1)
    end
  end
end
