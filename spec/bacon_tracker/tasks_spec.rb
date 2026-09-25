require 'spec_helper'

RSpec.describe BaconTracker::Tasks do
  # Each example gets a fresh Rake application and a clean module-level config
  # so installs can't leak across examples (or into other spec files).
  around do |example|
    original_app = Rake.application
    Rake.application = Rake::Application.new
    example.run
  ensure
    Rake.application = original_app
    BaconTracker.instance_variable_set(:@config, nil)
  end

  def tracker_root(base, name)
    root = File.join(base, name)
    %w[features bugs chores].each do |kind|
      ext = kind == 'features' ? '.feature' : '.md'
      FileUtils.mkdir_p("#{root}/#{kind}/1_icebox")
      File.write("#{root}/#{kind}/_template#{ext}",
                 ext == '.feature' ? "Feature: Name the Feature\n" : "Title: placeholder\n")
    end
    File.write("#{root}/.next-id", '1')
    File.write("#{root}/backlog.md", '')
    root
  end

  describe 'BT-063: install_for_dashboard without NS' do
    it 'does not abort at load and still defines the dashboard server task' do
      saved = ENV.values_at('NS', 'NAMESPACE') # restore afterwards - these are process-global
      ENV.delete('NS')
      ENV.delete('NAMESPACE')
      Dir.mktmpdir do |base|
        dash = File.join(base, 'dashboard.md')
        File.write(dash, "## Demo\npath: #{tracker_root(base, 'demo')}\nnamespace: DMO\n")

        expect { BaconTracker::Tasks.install_for_dashboard(dash) }.not_to raise_error
        expect(Rake::Task.task_defined?('story:dashboard_server')).to be(true)
        expect(Rake::Task.task_defined?('story:feature')).to be(false)
      end
    ensure
      ENV['NS'], ENV['NAMESPACE'] = saved
    end
  end

  describe 'BT-057: repeated install' do
    it 'does not stack duplicate task actions' do
      Dir.mktmpdir do |base|
        BaconTracker.configure { |c| c.namespace = 'AAA'; c.tracker_root = tracker_root(base, 'a') }
        BaconTracker::Tasks.install
        BaconTracker.configure { |c| c.namespace = 'BBB'; c.tracker_root = tracker_root(base, 'b') }
        BaconTracker::Tasks.install

        expect(Rake::Task['story:chore'].actions.size).to eq(1)
        silence_output { Rake::Task['story:chore'].invoke('Only once') }
        expect(Dir.glob("#{base}/b/chores/1_icebox/BBB-*.md").size).to eq(1)
        expect(Dir.glob("#{base}/a/chores/1_icebox/*.md")).to be_empty
      end
    end

    it 'snapshots the config at install time so later mutation does not leak' do
      Dir.mktmpdir do |base|
        root_a = tracker_root(base, 'a')
        root_b = tracker_root(base, 'b')
        BaconTracker.configure { |c| c.namespace = 'AAA'; c.tracker_root = root_a }
        BaconTracker::Tasks.install
        BaconTracker.configure { |c| c.tracker_root = root_b }

        silence_output { Rake::Task['story:chore'].invoke('Snapshot test') }
        expect(Dir.glob("#{root_a}/chores/1_icebox/AAA-*.md").size).to eq(1)
        expect(Dir.glob("#{root_b}/chores/1_icebox/*.md")).to be_empty
      end
    end
  end

  describe 'BT-105: story:migrate' do
    it 'assigns IDs, skips already-frontmattered files, and reconciles backlog.md' do
      Dir.mktmpdir do |base|
        root = tracker_root(base, 'proj')
        FileUtils.mkdir_p("#{root}/bugs/2_backlog")
        File.write("#{root}/bugs/2_backlog/login.md", "Title: Login\n") # unmigrated
        File.write("#{root}/bugs/2_backlog/paid.md", "---\nid: NONE\n---\n\nPaid\n") # already has frontmatter
        BaconTracker.configure { |c| c.namespace = 'PRJ'; c.tracker_root = root }
        BaconTracker::Tasks.install

        silence_output { Rake::Task['story:migrate'].invoke }

        migrated = Dir.glob("#{root}/bugs/2_backlog/PRJ-*.md")
        expect(migrated.size).to eq(1)                                       # only login.md
        expect(File.read(migrated.first)).to start_with("---\nid: PRJ-")
        expect(File.exist?("#{root}/bugs/2_backlog/paid.md")).to be(true)    # not doubled/renamed
        expect(File.read("#{root}/bugs/2_backlog/paid.md")).to eq("---\nid: NONE\n---\n\nPaid\n")
        expect(File.read("#{root}/backlog.md")).to match(/PRJ-\d+ login/i)   # reconciled
      end
    end
  end

  describe 'BT-096: story:lint' do
    it 'reports a clean backlog without exiting non-zero' do
      Dir.mktmpdir do |base|
        root = tracker_root(base, 'proj')
        BaconTracker.configure { |c| c.namespace = 'PRJ'; c.tracker_root = root }
        BaconTracker::Tasks.install
        expect { silence_output { Rake::Task['story:lint'].invoke } }.not_to raise_error
      end
    end

    it 'exits non-zero on a phantom backlog line (no matching file in 2_backlog)' do
      Dir.mktmpdir do |base|
        root = tracker_root(base, 'proj')
        File.write("#{root}/backlog.md", "- PRJ-001 ghost story\n") # no file on disk
        BaconTracker.configure { |c| c.namespace = 'PRJ'; c.tracker_root = root }
        BaconTracker::Tasks.install
        expect { silence_errors { Rake::Task['story:lint'].invoke } }.to raise_error(SystemExit)
      end
    end
  end

  describe 'BT-121: story:lint relationship checks' do
    def chore(root, id, stage, blocked_by: nil)
      FileUtils.mkdir_p("#{root}/chores/#{stage}")
      fm = ["id: #{id}", 'type: chore', "status: #{BaconTracker::STATUS_MAP[stage]}"]
      fm << "blocked_by: #{blocked_by}" if blocked_by
      File.write("#{root}/chores/#{stage}/#{id}-thing.md", "---\n#{fm.join("\n")}\n---\n\nbody\n")
    end

    def lint(root)
      BaconTracker.configure { |c| c.namespace = 'PRJ'; c.tracker_root = root }
      BaconTracker::Tasks.install
      Rake::Task['story:lint'].invoke
    end

    it 'exits non-zero when a blocker is already done' do
      Dir.mktmpdir do |base|
        root = tracker_root(base, 'proj')
        chore(root, 'PRJ-001', '4_done')
        chore(root, 'PRJ-002', '1_icebox', blocked_by: 'PRJ-001')
        File.write("#{root}/.next-id", '3')
        expect { silence_errors { silence_output { lint(root) } } }.to raise_error(SystemExit)
      end
    end

    # The flow doc calls blocked-plus-moving a legitimate state. Failing CI on
    # it would train people to ignore lint, so it reports and exits clean.
    it 'reports a started story waiting on a blocker without failing the build' do
      Dir.mktmpdir do |base|
        root = tracker_root(base, 'proj')
        chore(root, 'PRJ-001', '1_icebox')
        chore(root, 'PRJ-002', '3_started', blocked_by: 'PRJ-001')
        File.write("#{root}/.next-id", '3')
        err = StringIO.new
        original = $stderr
        $stderr = err
        begin
          expect { silence_output { lint(root) } }.not_to raise_error
        ensure
          $stderr = original
        end
        expect(err.string).to match(/blocked-started: PRJ-002 is started but waits on PRJ-001/)
      end
    end
  end

  describe 'BT-123: LINT_FORMAT=github' do
    around do |example|
      saved = ENV.values_at('LINT_FORMAT', 'GITHUB_WORKSPACE')
      example.run
    ensure
      ENV['LINT_FORMAT'], ENV['GITHUB_WORKSPACE'] = saved
    end

    def drifted(root)
      FileUtils.mkdir_p("#{root}/chores/3_started")
      File.write("#{root}/chores/3_started/PRJ-001-x.md",
                 "---\nid: PRJ-001\ntype: chore\nstatus: backlog\n---\n\nbody\n")
      File.write("#{root}/.next-id", '2')
    end

    def lint_output(root)
      BaconTracker.configure { |c| c.namespace = 'PRJ'; c.tracker_root = root }
      BaconTracker::Tasks.install
      out = StringIO.new
      original = $stdout
      $stdout = out
      begin
        silence_errors { Rake::Task['story:lint'].invoke }
      rescue SystemExit # rubocop:disable Lint/SuppressedException
      ensure
        $stdout = original
      end
      out.string
    end

    it 'annotates the offending file and line instead of writing to stderr' do
      Dir.mktmpdir do |base|
        root = tracker_root(base, 'proj')
        drifted(root)
        ENV['LINT_FORMAT'] = 'github'
        ENV['GITHUB_WORKSPACE'] = root

        # status: is line 4 of the file written above.
        expect(lint_output(root))
          .to match(%r{^::error file=chores/3_started/PRJ-001-x\.md,line=4::status-drift: PRJ-001})
      end
    end

    it 'emits a flow signal as ::notice so the check annotates without failing' do
      Dir.mktmpdir do |base|
        root = tracker_root(base, 'proj')
        FileUtils.mkdir_p("#{root}/chores/1_icebox")
        File.write("#{root}/chores/1_icebox/PRJ-001-x.md",
                   "---\nid: PRJ-001\ntype: chore\nstatus: icebox\n---\n\nbody\n")
        FileUtils.mkdir_p("#{root}/chores/3_started")
        File.write("#{root}/chores/3_started/PRJ-002-x.md",
                   "---\nid: PRJ-002\ntype: chore\nstatus: started\nblocked_by: PRJ-001\n---\n\nbody\n")
        File.write("#{root}/.next-id", '3')
        ENV['LINT_FORMAT'] = 'github'
        ENV['GITHUB_WORKSPACE'] = root

        out = lint_output(root)
        expect(out).to match(/^::notice .*blocked-started: PRJ-002/)
        expect(out).not_to match(/^::error/)
      end
    end

    it 'writes nothing in workflow-command form unless LINT_FORMAT asks for it' do
      Dir.mktmpdir do |base|
        root = tracker_root(base, 'proj')
        drifted(root)
        ENV.delete('LINT_FORMAT')

        expect(lint_output(root)).not_to match(/^::(error|notice)/)
      end
    end
  end

  describe 'BT-123: annotation helpers' do
    it 'escapes the message and the property values' do
      line = BaconTracker::Tasks.github_annotation(
        text: '100% wrong, really: yes', path: nil, line: nil, severity: :error
      )
      expect(line).to eq('::error::100%25 wrong, really: yes')
    end

    it 'omits file= for a path outside the workspace rather than pointing at the wrong file' do
      Dir.mktmpdir do |outside|
        Dir.mktmpdir do |workspace|
          ENV['GITHUB_WORKSPACE'] = workspace
          begin
            stray = File.join(outside, 'story.md')
            expect(BaconTracker::Tasks.relative_path(stray)).to be_nil
            expect(BaconTracker::Tasks.github_annotation(text: 'x', path: stray, line: 3, severity: :error))
              .to eq('::error::x')
          ensure
            ENV.delete('GITHUB_WORKSPACE')
          end
        end
      end
    end

    it 'returns nil for a line lookup on a file that does not exist' do
      expect(BaconTracker::Tasks.line_matching('/nonexistent/story.md', /status:/)).to be_nil
    end
  end

  describe 'BT-121: relationship_message' do
    it 'renders a cycle as a closed chain' do
      msg = BaconTracker::Tasks.relationship_message(kind: :cycle, id: 'PRJ-001', cycle: %w[PRJ-001 PRJ-002])
      expect(msg).to eq('cycle: PRJ-001 → PRJ-002 → PRJ-001 - none of these can ever start')
    end

    it 'names the field a dangling reference came from' do
      msg = BaconTracker::Tasks.relationship_message(kind: :dangling, id: 'PRJ-002', ref: 'PRJ-999', field: 'linked_to')
      expect(msg).to match(/PRJ-002 linked_to names PRJ-999/)
    end
  end
end
