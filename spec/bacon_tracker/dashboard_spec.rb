require 'spec_helper'
require 'bacon_tracker/dashboard'

RSpec.describe BaconTracker::Dashboard do
  describe 'BT-063: relative project paths' do
    it 'resolves them against the dashboard.md directory, not the process CWD' do
      Dir.mktmpdir do |base|
        home = File.join(base, 'home')
        FileUtils.mkdir_p(File.join(home, 'tracker'))
        dash = File.join(home, 'dashboard.md')
        File.write(dash, "## My App\npath: ./tracker\nnamespace: AAA\n")

        Dir.chdir(base) do
          project = described_class.new(dash).projects.first
          expect(project.path).to eq(File.join(home, 'tracker'))
        end
      end
    end
  end

  describe 'BT-058: colliding project slugs' do
    it 'gives every project a unique slug and routes each to its own root' do
      Dir.mktmpdir do |base|
        root_a = File.join(base, 'a')
        root_b = File.join(base, 'b')
        FileUtils.mkdir_p(root_a)
        FileUtils.mkdir_p(root_b)
        # Registry entries in the pre-BT-ADR-0016 form: `path:` points straight
        # at the tracker directory, which the compatibility rule detects.
        File.write(File.join(root_a, 'backlog.md'), '')
        File.write(File.join(root_b, 'backlog.md'), '')
        dash = File.join(base, 'dashboard.md')
        File.write(dash, <<~MD)
          ## My App
          path: #{root_a}
          namespace: AAA

          ## My-App
          path: #{root_b}
          namespace: BBB
        MD

        dashboard = described_class.new(dash)
        slugs = dashboard.projects.map(&:slug)
        expect(slugs.uniq.size).to eq(2)

        roots = slugs.map { |s| dashboard.project_core(s).config.tracker_root }
        expect(roots).to contain_exactly(root_a, root_b)
      end
    end
  end

  describe 'BT-086: invalid project entries' do
    it 'skips a project whose name yields an empty namespace and none is given' do
      Dir.mktmpdir do |base|
        dash = File.join(base, 'dashboard.md')
        File.write(dash, "## +++\npath: #{base}/weird\n\n## Good\npath: #{base}/good\nnamespace: GD\n")
        projects = silence_errors { described_class.new(dash).projects }
        expect(projects.map(&:name)).to eq(['Good'])
        expect(projects.map(&:namespace)).not_to include('')
      end
    end

    it 'warns instead of silently dropping a project with no path:' do
      Dir.mktmpdir do |base|
        dash = File.join(base, 'dashboard.md')
        File.write(dash, "## Good\npath: #{base}/good\nnamespace: GD\n\n## NoPath\nnamespace: NP\n")
        original = $stderr
        $stderr = StringIO.new
        begin
          projects = described_class.new(dash).projects
          warning  = $stderr.string
        ensure
          $stderr = original
        end
        expect(projects.map(&:name)).to eq(['Good'])
        expect(warning).to match(/NoPath.*path/i)
      end
    end
  end
end

RSpec.describe "#{BaconTracker::Dashboard} roots (BT-134, BT-ADR-0016)" do
  def dashboard_for(base, entry)
    dash = File.join(base, 'dashboard.md')
    File.write(dash, entry)
    BaconTracker::Dashboard.new(dash)
  end

  it 'defaults to tracker/ and docs/ beside the project path' do
    Dir.mktmpdir do |base|
      proj = File.join(base, 'app')
      FileUtils.mkdir_p(File.join(proj, 'tracker'))
      FileUtils.mkdir_p(File.join(proj, 'docs'))

      p = dashboard_for(base, "## App\npath: ./app\nnamespace: APP\n").projects.first
      expect(p.tracker_root).to eq(File.join(proj, 'tracker'))
      expect(p.docs_root).to eq(File.join(proj, 'docs'))
      expect(p.tracker?).to be(true)
      expect(p.docs?).to be(true)
    end
  end

  it 'lets either key override the default, including across repositories' do
    Dir.mktmpdir do |base|
      proj = File.join(base, 'app')
      FileUtils.mkdir_p(File.join(base, 'elsewhere', 'stories'))
      FileUtils.mkdir_p(File.join(proj, 'documentation'))

      p = dashboard_for(base,
                        "## App\npath: ./app\nnamespace: APP\ntracker: ../elsewhere/stories\ndocs: documentation\n").projects.first
      expect(p.tracker_root).to eq(File.join(base, 'elsewhere', 'stories'))
      expect(p.docs_root).to eq(File.join(proj, 'documentation'))
    end
  end

  # An absent default means "this project has no docs" - silent. An explicit key
  # pointing nowhere is a typo, and warns like a missing path: does.
  it 'is silent when a default root is absent' do
    Dir.mktmpdir do |base|
      FileUtils.mkdir_p(File.join(base, 'app', 'tracker'))
      p = nil
      expect { p = dashboard_for(base, "## App\npath: ./app\nnamespace: APP\n").projects.first }
        .not_to output.to_stderr
      expect(p.docs?).to be(false)
      expect(p.tracker?).to be(true)
    end
  end

  it 'warns when an explicit root does not exist' do
    Dir.mktmpdir do |base|
      FileUtils.mkdir_p(File.join(base, 'app', 'tracker'))
      expect { dashboard_for(base, "## App\npath: ./app\nnamespace: APP\ndocs: nope\n").projects }
        .to output(/docs/).to_stderr
    end
  end

  it 'excludes the tracker tree from the docs tree when it sits inside it' do
    Dir.mktmpdir do |base|
      proj = File.join(base, 'app')
      FileUtils.mkdir_p(File.join(proj, 'docs', 'tracker'))
      p = dashboard_for(base, "## App\npath: ./app\nnamespace: APP\ntracker: docs/tracker\n").projects.first
      expect(p.tracker_inside_docs?).to be(true)
    end
  end

  it 'does not exclude anything when the roots are siblings' do
    Dir.mktmpdir do |base|
      proj = File.join(base, 'app')
      FileUtils.mkdir_p(File.join(proj, 'tracker'))
      FileUtils.mkdir_p(File.join(proj, 'docs'))
      p = dashboard_for(base, "## App\npath: ./app\nnamespace: APP\n").projects.first
      expect(p.tracker_inside_docs?).to be(false)
    end
  end
end

RSpec.describe "#{BaconTracker::Dashboard} registry compatibility (BT-134)" do
  it 'treats a path that is itself a tracker directory as the tracker root' do
    Dir.mktmpdir do |base|
      legacy = File.join(base, 'app', 'docs', 'tracker')
      FileUtils.mkdir_p(legacy)
      File.write(File.join(legacy, 'backlog.md'), '')
      dash = File.join(base, 'dashboard.md')
      File.write(dash, "## App\npath: ./app/docs/tracker\nnamespace: APP\n")

      p = BaconTracker::Dashboard.new(dash).projects.first
      expect(p.tracker_root).to eq(legacy)
      expect(p.path).to eq(File.join(base, 'app', 'docs'))
      expect(p.tracker?).to be(true)
    end
  end

  it 'lets an explicit tracker: win over the legacy detection' do
    Dir.mktmpdir do |base|
      legacy = File.join(base, 'app')
      FileUtils.mkdir_p(File.join(legacy, 'elsewhere'))
      File.write(File.join(legacy, 'backlog.md'), '')
      File.write(File.join(legacy, 'elsewhere', 'backlog.md'), '')
      dash = File.join(base, 'dashboard.md')
      File.write(dash, "## App\npath: ./app\nnamespace: APP\ntracker: elsewhere\n")

      p = BaconTracker::Dashboard.new(dash).projects.first
      expect(p.tracker_root).to eq(File.join(legacy, 'elsewhere'))
    end
  end
end
