require 'spec_helper'
require 'bacon_tracker/dashboard'

# Regressions found in the pre-release review (BT-179). Each example pins one
# defect that shipped past the rest of the suite.
RSpec.describe 'pre-release review fixes (BT-179)' do
  describe 'Tasks.install_for_dashboard with NS' do
    around do |example|
      original_app = Rake.application
      Rake.application = Rake::Application.new
      saved = ENV['NS']
      example.run
    ensure
      ENV['NS'] = saved
      Rake.application = original_app
      BaconTracker.instance_variable_set(:@config, nil)
    end

    it 'configures the same roots as the server, for both path: forms' do
      Dir.mktmpdir do |base|
        proj = File.join(base, 'proj')
        FileUtils.mkdir_p(File.join(proj, 'tracker'))
        File.write(File.join(proj, 'tracker', '.next-id'), '1')
        FileUtils.mkdir_p(File.join(proj, 'docs', 'decisions'))

        { 'project root' => proj, 'legacy tracker path' => File.join(proj, 'tracker') }.each do |_form, path|
          dash = File.join(base, 'dashboard.md')
          File.write(dash, "## Proj\npath: #{path}\nnamespace: PRJ\n")
          ENV['NS'] = 'PRJ'
          BaconTracker::Tasks.install_for_dashboard(dash)

          c = BaconTracker.config
          expect(c.tracker_root).to eq(File.join(proj, 'tracker'))
          expect(c.decisions_root).to eq(File.join(proj, 'docs', 'decisions'))
          expect(c.project_root).to eq(proj)
        end
      end
    end

    it 'clears decision tasks on reinstall, so decision:new runs once' do
      Dir.mktmpdir do |base|
        BaconTracker.configure { |c| c.namespace = 'AAA'; c.tracker_root = base }
        2.times { BaconTracker::Tasks.install }
        expect(Rake::Task['decision:new'].actions.size).to eq(1)
      end
    end
  end

  describe 'markdown sanitising' do
    let(:core) { BaconTracker::Core.new(BaconTracker::Configuration.new) }

    it 'drops raw HTML, event handlers and script URLs' do
      html = core.render_markdown(<<~MD)
        # Title

        <script>alert(1)</script>

        <img src=x onerror="alert(2)">

        [bad](javascript:alert(3)) [tab](java\tscript:alert(4)) [data](data:text/html,x)

        [ial](https://example.com){: onclick="alert(5)"}

        {::nomarkdown}<b onmouseover="alert(6)">x</b>{:/}
      MD
      expect(html).not_to match(/<script|onerror|onclick|onmouseover|javascript:|data:text/i)
      expect(html).to include('<h1', 'https://example.com')
    end

    it 'keeps what markdown itself produces: task lists, links, code' do
      html = core.render_markdown("- [ ] open\n- [x] done\n\n[rel](guide.md) [ext](https://x.org) [m](mailto:a@b.c)\n\n`<b>`\n")
      expect(html.scan(/type="checkbox"/).size).to eq(2)
      expect(html.scan('disabled="disabled"').size).to eq(2)
      expect(html).to include('href="guide.md"', 'href="https://x.org"', 'href="mailto:a@b.c"', '&lt;b&gt;')
    end

    it 'strips anything an author adds to a checkbox' do
      html = core.render_markdown(%(<input type="checkbox" onclick="alert(1)" formaction="x">\n))
      expect(html).not_to include('onclick', 'formaction')
    end
  end

  describe 'frontmatter values' do
    it 'keeps a long blocked_by on one line across edits' do
      with_fixture_repo do |core, _|
        silence_output { core.create('bug', 'Target') }
        ids = (2..14).map { |i| format('TST-%03d', i) }
        core.update_story('TST-001', blocked_by: ids)
        core.update_story('TST-001', blocked_by: ['TST-002'])
        story = core.all_stories.find { |s| s[:id] == 'TST-001' }
        expect(story[:blocked_by]).to eq(['TST-002'])
        expect(File.read(story[:path])).not_to match(/^\s+TST-01/)
      end
    end

    it 'reads a hand-authored YAML list for blocked_by and linked_to' do
      with_fixture_repo do |core, root|
        File.write("#{root}/bugs/1_icebox/TST-001-x.md",
                   "---\nid: TST-001\ntype: bug\nstatus: icebox\nblocked_by: [TST-002, TST-003]\nlinked_to: [TST-004]\n---\n\nTitle: x\n")
        story = core.all_stories.first
        expect(story[:blocked_by]).to eq(%w[TST-002 TST-003])
        expect(story[:linked_to]).to eq(%w[TST-004])
      end
    end
  end

  describe 'Core#set_stage' do
    it 'leaves the file where it was when the status cannot be written' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/TST-001-broken.md"
        File.write(path, "---\nid: TST-001\nno closing fence\n")
        expect { core.set_stage('TST-001', '2_backlog') }.to raise_error(ArgumentError, /malformed/)
        expect(File.exist?(path)).to be(true)
        expect(Dir.glob("#{root}/bugs/2_backlog/*.md")).to be_empty
      end
    end
  end

  describe 'Core#stats next_task' do
    it 'ignores a heading that merely mentions an id' do
      with_fixture_repo do |core, root|
        File.write("#{root}/backlog.md", "# Backlog (see TST-099)\n\n- TST-001 real one\n")
        expect(core.stats[:next_task]).to eq('real one')
        expect(core.backlog_lines.map(&:strip)).to eq(['- TST-001 real one'])
      end
    end
  end

  describe 'decisions' do
    it 'creates a missing status directory before transitioning' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'proposed', id: 1)
        FileUtils.rm_rf(File.join(core.config.decisions_root, 'accepted'))
        core.set_status('TST-ADR-0001', 'accepted')
        expect(core.decisions.first).to include(stage: 'accepted', declared: 'accepted')
      end
    end

    it 'refuses to transition a record without frontmatter with a clean error' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'proposed', id: 1, frontmatter: '')
        expect { core.set_status('TST-ADR-0001', 'accepted') }.to raise_error(ArgumentError, /no frontmatter/)
      end
    end

    it 'gives a non-ASCII title a real filename and keeps backslashes verbatim' do
      with_fixture_repo(decisions: true) do |core, _|
        path = core.create_decision('日本語')
        expect(File.basename(path)).to eq('TST-ADR-0001-untitled.md')
        path = core.create_decision('Use C:\temp \0 and \&')
        expect(File.read(path)).to include('# Use C:\temp \0 and \&')
      end
    end
  end

  describe 'Configuration roots' do
    it 'expands ~ and relative paths on assignment' do
      c = BaconTracker::Configuration.new
      c.tracker_root = '~/proj/tracker'
      c.docs_root    = 'docs'
      expect(c.tracker_root).to eq(File.join(Dir.home, 'proj', 'tracker'))
      expect(c.docs_root).to eq(File.join(Dir.pwd, 'docs'))
      c.decisions_root = nil
      expect(c.decisions_root).to be_nil
    end
  end

  describe 'Dashboard encoding' do
    it 'parses a UTF-8 dashboard.md under an ASCII locale' do
      Dir.mktmpdir do |base|
        dash = File.join(base, 'dashboard.md')
        File.write(dash, "## Café Project\npath: #{base}\nnamespace: CAF\n")
        saved = Encoding.default_external
        begin
          silence_errors { Encoding.default_external = Encoding::US_ASCII }
          expect(BaconTracker::Dashboard.new(dash).projects.first.name).to eq('Café Project')
        ensure
          silence_errors { Encoding.default_external = saved }
        end
      end
    end
  end

  describe 'docs symlinks' do
    it 'refuses a page whose symlink points outside the docs root' do
      with_fixture_repo(decisions: true) do |core, root|
        docs = File.dirname(core.config.decisions_root)
        core.config.docs_root = docs
        outside = File.join(root, 'secret.md')
        File.write(outside, "# secret\n")
        File.symlink(outside, File.join(docs, 'leak.md'))
        FileUtils.mkdir_p(File.join(root, 'elsewhere'))
        File.write(File.join(root, 'elsewhere', 'x.md'), "# x\n")
        File.symlink(File.join(root, 'elsewhere'), File.join(docs, 'linked-dir'))

        expect { core.render_page('leak.md') }.to raise_error(ArgumentError, /outside/)
        expect(core.docs_tree.map { |n| n[:name] }).not_to include('linked-dir')
      end
    end
  end
end
