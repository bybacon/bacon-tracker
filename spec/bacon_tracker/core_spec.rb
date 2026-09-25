require 'spec_helper'

RSpec.describe BaconTracker::Core do
  describe '#slugify' do
    it 'lowercases and replaces non-alphanumeric runs with dashes' do
      config = BaconTracker::Configuration.new
      core = BaconTracker::Core.new(config)
      expect(core.slugify('Hello World!')).to eq('hello-world')
      expect(core.slugify('  Foo -- Bar  ')).to eq('foo-bar')
    end
  end

  describe '#format_id' do
    it 'zero-pads to three digits with the configured namespace' do
      config = BaconTracker::Configuration.new
      config.namespace = 'TST'
      core = BaconTracker::Core.new(config)
      expect(core.format_id(1)).to eq('TST-001')
      expect(core.format_id(42)).to eq('TST-042')
    end
  end

  describe '#consume_id' do
    it 'returns current ID and increments .next-id' do
      with_fixture_repo do |core, root|
        expect(core.consume_id).to eq(1)
        expect(core.consume_id).to eq(2)
        expect(File.read("#{root}/.next-id").strip).to eq('3')
      end
    end

    it 'produces unique IDs under concurrent access' do
      with_fixture_repo do |core, root|
        ids = Array.new(10).map { Thread.new { core.consume_id } }.map(&:value)
        expect(ids.uniq.size).to eq(10)
      end
    end
  end

  describe '#next_id_value' do
    it 'returns 1 when .next-id is absent' do
      with_fixture_repo do |core, root|
        File.delete("#{root}/.next-id")
        expect(core.next_id_value).to eq(1)
      end
    end

    it 'returns 1 when .next-id is blank (same floor as consume_id)' do
      with_fixture_repo do |core, root|
        File.write("#{root}/.next-id", '')
        expect(core.next_id_value).to eq(1)
      end
    end

    it 'returns the stored value when non-zero' do
      with_fixture_repo do |core, root|
        File.write("#{root}/.next-id", '7')
        expect(core.next_id_value).to eq(7)
      end
    end
  end

  describe '#create' do
    it 'creates a feature file in 1_icebox with frontmatter and title substitution' do
      with_fixture_repo do |core, root|
        silence_output { core.create('feature', 'My Feature') }
        files = Dir.glob("#{root}/features/1_icebox/TST-001-*.feature")
        expect(files.size).to eq(1)
        content = File.read(files.first)
        expect(content).to include('# id: TST-001')
        expect(content).to include('# status: icebox')
        expect(content).to include('My Feature')
      end
    end

    it 'creates a bug file with YAML frontmatter' do
      with_fixture_repo do |core, root|
        silence_output { core.create('bug', 'Login crash') }
        files = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md")
        expect(files.size).to eq(1)
        content = File.read(files.first)
        expect(content).to include('id: TST-001')
        expect(content).to include('type: bug')
        expect(content).to include('status: icebox')
      end
    end

    it 'sets fields (size/assignee/blocked_by) at create time' do
      with_fixture_repo do |core, root|
        silence_output do
          core.create('feature', 'Sized Thing', size: 'm', assignee: 'AB', blocked_by: ['TST-009'])
        end
        content = File.read(Dir.glob("#{root}/features/1_icebox/TST-001-*.feature").first)
        expect(content).to include('# size: M')
        expect(content).to include('# assignee: AB')
        expect(content).to include('# blocked_by: TST-009')
      end
    end

    it 'reports the created ID when a field fails validation' do
      with_fixture_repo do |core, root|
        expect { core.create('feature', 'Bad Size', size: 'XL') }
          .to raise_error(SystemExit)
          .and output(/Created TST-001 but could not set fields/).to_stderr
        # the story is still created (icebox is cheap) - only the field failed
        expect(Dir.glob("#{root}/features/1_icebox/TST-001-*")).not_to be_empty
      end
    end
  end

  describe '#edit_assignments' do
    let(:core) { BaconTracker::Core.new(BaconTracker::Configuration.new) }

    it 'maps simple field=value tokens to update_story kwargs' do
      expect(core.edit_assignments(['size=M', 'assignee=AB']))
        .to eq(size: 'M', assignee: 'AB')
    end

    it 're-stitches a comma-separated blocked_by that rake split into bare tokens' do
      expect(core.edit_assignments(['blocked_by=TST-002', 'TST-003']))
        .to eq(blocked_by: ['TST-002', 'TST-003'])
    end

    it 're-stitches a comma-separated linked_to that rake split into bare tokens' do
      expect(core.edit_assignments(['linked_to=TST-002', 'TST-003']))
        .to eq(linked_to: ['TST-002', 'TST-003'])
    end

    it 'keeps an empty value so the field is removed downstream' do
      expect(core.edit_assignments(['size='])).to eq(size: '')
    end

    it 'passes a body value through as-is (single logical line)' do
      expect(core.edit_assignments(['body=just a note'])).to eq(body: 'just a note')
    end

    it 'returns empty when given no tokens' do
      expect(core.edit_assignments([])).to eq({})
    end

    it 'raises on an unknown field' do
      expect { core.edit_assignments(['colour=blue']) }
        .to raise_error(ArgumentError, /Unknown field/)
    end

    it "keeps '=' inside a value instead of starting a spurious field (BT-106)" do
      # rake splits "title=Compare a=1, b=2" on the comma
      expect(core.edit_assignments(['title=Compare a=1', ' b=2']))
        .to eq(title: 'Compare a=1, b=2')
    end

    it 'raises on a bare token instead of silently dropping it (BT-106)' do
      expect { core.edit_assignments(['M']) }.to raise_error(ArgumentError, /field=value/)
    end
  end

  describe '#find_story' do
    it 'returns nil when no story matches' do
      with_fixture_repo do |core, _|
        expect(core.find_story('TST-999')).to be_nil
      end
    end

    it 'finds a story in any stage' do
      with_fixture_repo do |core, root|
        File.write("#{root}/features/1_icebox/TST-001-a.feature", "# id: TST-001\n")
        File.write("#{root}/bugs/3_started/TST-002-b.md",  "---\nid: TST-002\n---\n")
        File.write("#{root}/chores/4_done/TST-003-c.md",   "---\nid: TST-003\n---\n")
        expect(core.find_story('TST-001')[:stage]).to eq('1_icebox')
        expect(core.find_story('TST-002')[:stage]).to eq('3_started')
        expect(core.find_story('TST-003')[:stage]).to eq('4_done')
        expect(core.find_story('TST-999')).to be_nil
      end
    end
  end

  describe '#parse_story_file' do
    it 'parses a .feature file: extracts id, type, stage, and body' do
      with_fixture_repo do |core, root|
        path = "#{root}/features/1_icebox/TST-001-my-feature.feature"
        File.write(path, "# id: TST-001\n# type: feature\n# status: icebox\n\nFeature: My Feature\n  Scenario: pass\n")
        d = { type: 'feature', ext: '.feature', stage: '1_icebox', dir: 'features' }
        story = core.parse_story_file(path, d)
        expect(story[:id]).to eq('TST-001')
        expect(story[:type]).to eq('feature')
        expect(story[:stage]).to eq('1_icebox')
        expect(story[:body]).to include('Feature: My Feature')
      end
    end

    it 'parses a .feature file authored with YAML frontmatter (linked_to badge fix)' do
      with_fixture_repo do |core, root|
        path = "#{root}/features/3_started/TST-001-observability.feature"
        File.write(path, "---\nid: TST-001\ntype: feature\nstatus: started\n" \
                         "size: L\nassignee: AB\nlinked_to: TST-002, TST-003\n---\n\n" \
                         "Feature: Observability\n  Scenario: pass\n")
        d = { type: 'feature', ext: '.feature', stage: '3_started', dir: 'features' }
        story = core.parse_story_file(path, d)
        expect(story[:linked_to]).to eq(%w[TST-002 TST-003])
        expect(story[:size]).to eq('L')
        expect(story[:assignee]).to eq('AB')
        expect(story[:declared_status]).to eq('started')
        expect(story[:body]).to start_with('Feature: Observability')
      end
    end

    it 'parses a .md file: extracts id, type, stage, and body' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/2_backlog/TST-002-login-crash.md"
        File.write(path, "---\nid: TST-002\ntype: bug\nstatus: backlog\n---\n\nSomething broke.\n")
        d = { type: 'bug', ext: '.md', stage: '2_backlog', dir: 'bugs' }
        story = core.parse_story_file(path, d)
        expect(story[:id]).to eq('TST-002')
        expect(story[:type]).to eq('bug')
        expect(story[:body]).to eq("Something broke.\n")
      end
    end

    it 'returns nil for a file without the namespace prefix' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/_template.md"
        File.write(path, "---\nid: \n---\n")
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }
        expect(core.parse_story_file(path, d)).to be_nil
      end
    end

    it 'tolerates a malformed .feature header line instead of raising (BT-078)' do
      with_fixture_repo do |core, root|
        # '# type:bug' matches the header guard /^# \w+:/ but has no ': ' to split on
        path = "#{root}/features/1_icebox/TST-001-malformed.feature"
        File.write(path, "# id: TST-001\n# type:bug\n\nFeature: Malformed\n")
        d = { type: 'feature', ext: '.feature', stage: '1_icebox', dir: 'features' }
        story = nil
        expect { story = core.parse_story_file(path, d) }.not_to raise_error
        expect(story[:id]).to eq('TST-001')
        expect(story[:body]).to include('Feature: Malformed')
      end
    end

    it 'keeps all_stories up when one .feature header is malformed (BT-078)' do
      with_fixture_repo do |core, root|
        File.write("#{root}/features/1_icebox/TST-001-ok.feature",
                   "# id: TST-001\n# type: feature\n\nFeature: Fine\n")
        File.write("#{root}/features/1_icebox/TST-002-bad.feature",
                   "# id: TST-002\n# language:en\n\nFeature: Bad header\n")
        expect { core.all_stories }.not_to raise_error
        expect(core.all_stories.map { |s| s[:id] }).to include('TST-001', 'TST-002')
      end
    end
  end

  describe 'frontmatter value safety' do
    it 'preserves other fields when a value contains YAML-significant characters (BT-098)' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Colon Assignee', size: 'M')
        core.update_story('TST-001', assignee: 'Bob: reviewer')
        path = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").first
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }
        story = core.parse_story_file(path, d)
        expect(story[:size]).to eq('M') # not lost to a Psych parse error
        expect(story[:assignee]).to eq('Bob: reviewer')
      end
    end
  end

  describe 'atomic writes' do
    it 'leaves no temp files behind after story and backlog writes (BT-079)' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Atomic', stage: '2_backlog')
        core.update_story('TST-001', body: 'new body', size: 'M')
        leftover = Dir.glob("#{root}/**/*", File::FNM_DOTMATCH).select { |f| f.include?('.tmp') }
        expect(leftover).to be_empty
      end
    end

    it 'leaves the original file intact when the write fails mid-way (BT-079)' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Atomic')
        path     = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").first
        original = File.read(path)
        allow(File).to receive(:rename).and_raise(Errno::EIO)
        expect { core.update_story('TST-001', body: 'should not land') }.to raise_error(Errno::EIO)
        expect(File.read(path)).to eq(original)
        leftover = Dir.glob("#{root}/**/*", File::FNM_DOTMATCH).select { |f| f.include?('.tmp') }
        expect(leftover).to be_empty
      end
    end
  end

  describe 'workflow guards' do
    it "toggle_subtask raises ArgumentError (not NoMethodError) when the file can't be parsed (BT-080)" do
      with_fixture_repo do |core, root|
        # 'TST-x' matches find_story's '<id>-*' glob but fails the id pattern,
        # so parse_story_file returns nil.
        File.write("#{root}/bugs/1_icebox/TST-x-odd.md", "---\nid: TST-x\n---\n\n- [ ] a\n")
        expect { core.toggle_subtask('TST-x', 0, true) }.to raise_error(ArgumentError)
      end
    end

    it 'create_story rejects an invalid size like update_story (BT-101)' do
      with_fixture_repo do |core, root|
        expect { core.create_story('bug', 'Too big', size: 'XL') }
          .to raise_error(ArgumentError, /size must be S, M, or L/)
        expect(Dir.glob("#{root}/bugs/1_icebox/TST-*.md")).to be_empty # no ID burned
      end
    end

    it 'refuses to delete a done story (BT-081)' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/4_done/TST-001-shipped.md"
        File.write(path, "---\nid: TST-001\ntype: bug\nstatus: done\n---\n\nBody.\n")
        expect { core.delete_story('TST-001') }.to raise_error(ArgumentError, /permanent record|not deleted/)
        expect(File.exist?(path)).to be true
      end
    end

    it 'refuses to move a story out of 4_done (BT-102)' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/4_done/TST-001-shipped.md"
        File.write(path, "---\nid: TST-001\ntype: bug\nstatus: done\n---\n\nBody.\n")
        expect { core.set_stage('TST-001', '3_started') }.to raise_error(ArgumentError, /append-only|reopen/)
        expect(File.exist?(path)).to be true
      end
    end
  end

  describe 'data integrity' do
    it 'find_story refuses a traversal id and only accepts well-formed ids (BT-097)' do
      with_fixture_repo do |core, root|
        File.write("#{root}/TST-001-leak.md", 'leak') # outside the story dirs
        File.write("#{root}/bugs/1_icebox/TST-001-real.md", "---\nid: TST-001\n---\n\nx\n")
        expect(core.find_story('../../TST-001')).to be_nil # can't traverse out
        expect(core.find_story('TST-001')[:file]).to end_with('TST-001-real.md')
      end
    end

    it 'backlog_story_files matches when the namespace has glob metacharacters (BT-083)' do
      with_fixture_repo(namespace: 'B[T]') do |core, root|
        path = "#{root}/bugs/2_backlog/B[T]-001-x.md"
        File.write(path, "---\nid: B[T]-001\n---\n\nx\n")
        expect(core.backlog_story_files).to include(path)
      end
    end

    it 'backlog_reorder does not duplicate a line when an id repeats in the payload (BT-082)' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'One', stage: '2_backlog')
        core.create_story('bug', 'Two', stage: '2_backlog')
        core.backlog_reorder(['TST-001', 'TST-001', 'TST-002'])
        listed = File.readlines("#{root}/backlog.md").grep(/TST-001/)
        expect(listed.size).to eq(1)
      end
    end

    it 'backlog_add does not glue onto a backlog.md lacking a trailing newline (BT-103)' do
      with_fixture_repo do |core, root|
        File.write("#{root}/backlog.md", '- TST-009 old task')  # no trailing newline
        core.create_story('bug', 'New', stage: '2_backlog')     # backlog_add for TST-001
        lines = File.readlines("#{root}/backlog.md").map(&:chomp).reject(&:empty?)
        expect(lines).to include('- TST-009 old task')
        expect(lines.any? { |l| l.include?('TST-001') }).to be true
        expect(lines.size).to be >= 2 # not fused into one line
      end
    end

    it 'set_field_in only edits the .feature header block, not body comments (BT-099)' do
      with_fixture_repo do |core, root|
        path = "#{root}/features/1_icebox/TST-001-x.feature"
        File.write(path, "# id: TST-001\n# type: feature\n\nFeature: X\n# size: estimate later\n")
        core.set_frontmatter_field(path, 'size', 'M')
        content = File.read(path)
        expect(content).to include('# size: M')               # header field set
        expect(content).to include('# size: estimate later')  # body comment untouched
      end
    end

    it 'sets a field as YAML in a .feature file authored with YAML frontmatter' do
      with_fixture_repo do |core, root|
        path = "#{root}/features/3_started/TST-001-x.feature"
        File.write(path, "---\nid: TST-001\ntype: feature\nstatus: started\n---\n\nFeature: X\n")
        core.update_story('TST-001', linked_to: %w[TST-002])
        content = File.read(path)
        expect(content).to include('linked_to: TST-002') # YAML, not "# linked_to:"
        expect(content).not_to include('# linked_to')
        d = { type: 'feature', ext: '.feature', stage: '3_started', dir: 'features' }
        expect(core.parse_story_file(path, d)[:linked_to]).to eq(%w[TST-002])
      end
    end

    it 'preserves YAML frontmatter on a body edit of a .feature file' do
      with_fixture_repo do |core, root|
        path = "#{root}/features/3_started/TST-001-x.feature"
        File.write(path, "---\nid: TST-001\ntype: feature\nlinked_to: TST-002\n---\n\nFeature: X\n")
        core.update_story('TST-001', body: "Feature: X\n  Scenario: new\n")
        content = File.read(path)
        expect(content).to include('linked_to: TST-002') # frontmatter kept
        expect(content).to include('Scenario: new') # body replaced
        expect(content).not_to include('# linked_to')
      end
    end

    it 'update_story body edit raises on malformed frontmatter instead of fusing body into YAML (BT-100)' do
      with_fixture_repo do |core, root|
        path     = "#{root}/bugs/1_icebox/TST-001-x.md"
        original = "---\nid: TST-001\ntype: bug\n" # opening --- but no closing
        File.write(path, original)
        expect { core.update_story('TST-001', body: 'new body') }.to raise_error(ArgumentError, /frontmatter/)
        expect(File.read(path)).to eq(original) # left untouched
      end
    end

    it 'backlog_ids ignores ids mentioned in prose/comment lines (BT-107)' do
      with_fixture_repo do |core, root|
        File.write("#{root}/backlog.md",
                   "# Backlog\n- TST-001 real entry\n<!-- TST-999 archived note -->\n")
        expect(core.backlog_ids).to eq(['TST-001'])
      end
    end
  end

  describe 'markdown template' do
    it 'ships no live checkbox that would become a phantom subtask (BT-108)' do
      expect(BaconTracker::Templates.markdown('bug')).not_to match(/^\s*- \[[ xX]\]/)
    end

    it 'a story created from the fallback template has zero subtasks (BT-108)' do
      with_fixture_repo do |core, root|
        File.delete("#{root}/bugs/_template.md") # force the Templates fallback
        story = core.create_story('bug', 'No subtasks')
        expect(story[:subtasks]).to be_nil
      end
    end
  end

  describe 'data-shape edges (BT-095)' do
    it 'reads frontmatter despite a leading UTF-8 BOM' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/TST-001-bom.md"
        File.write(path, "\uFEFF---\nid: TST-001\ntype: bug\nsize: L\n---\n\nBody\n")
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }
        expect(core.parse_story_file(path, d)[:size]).to eq('L')
      end
    end

    it "uses an 'untitled' slug when the title has no ASCII alphanumerics" do
      with_fixture_repo do |core, _root|
        story = core.create_story('bug', '日本語')
        expect(File.basename(story[:path])).to eq('TST-001-untitled.md') # not a dangling "TST-001-.md"
        expect(core.find_story('TST-001')).not_to be_nil
      end
    end

    it 'removes a field set to an empty string instead of writing a blank line' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/TST-001-x.md"
        File.write(path, "---\nid: TST-001\ntype: bug\nassignee: Bob\n---\n\nBody\n")
        core.set_frontmatter_field(path, 'assignee', '')
        expect(File.read(path)).not_to match(/assignee:/)
      end
    end

    it 'does not crash all_stories on a file with invalid UTF-8 bytes (BT-096)' do
      with_fixture_repo do |core, root|
        File.binwrite("#{root}/bugs/1_icebox/TST-001-bad.md",
                      "---\nid: TST-001\ntype: bug\nsize: M\n---\n\nca\xFF\xFEfe\n")
        stories = nil
        expect { stories = core.all_stories }.not_to raise_error
        story = stories.find { |s| s[:id] == 'TST-001' }
        expect(story[:size]).to eq('M') # frontmatter still read after scrubbing the bad bytes
      end
    end
  end

  describe '#commit' do
    it 'moves an icebox story to 2_backlog, updates status, and appends to backlog.md' do
      with_fixture_repo do |core, root|
        silence_output { core.create('feature', 'New Thing') }
        id = 'TST-001'

        expect { core.commit(id) }.to output(/Committed TST-001/).to_stdout

        expect(Dir.glob("#{root}/features/1_icebox/TST-001-*")).to be_empty
        backlog_files = Dir.glob("#{root}/features/2_backlog/TST-001-*")
        expect(backlog_files.size).to eq(1)

        content = File.read(backlog_files.first)
        expect(content).to include('# status: backlog')

        backlog = File.read("#{root}/backlog.md")
        expect(backlog).to include('TST-001')
      end
    end

    it 'aborts when story is not in 1_icebox' do
      with_fixture_repo do |core, root|
        File.write("#{root}/features/2_backlog/TST-001-already-committed.feature",
                   "# id: TST-001\n# status: backlog\n")
        silence_errors { expect { core.commit('TST-001') }.to raise_error(SystemExit, /expected 1_icebox/) }
      end
    end
  end

  describe '#start' do
    it 'moves a backlog story to 3_started, updates status, and removes it from backlog.md' do
      with_fixture_repo do |core, root|
        silence_output do
          core.create('feature', 'New Thing')
          core.commit('TST-001')
        end

        expect { core.start('TST-001') }.to output(/Started TST-001/).to_stdout

        expect(Dir.glob("#{root}/features/2_backlog/TST-001-*")).to be_empty
        started_files = Dir.glob("#{root}/features/3_started/TST-001-*")
        expect(started_files.size).to eq(1)

        content = File.read(started_files.first)
        expect(content).to include('# status: started')

        backlog = File.read("#{root}/backlog.md")
        expect(backlog).not_to include('TST-001')
      end
    end

    it 'aborts when story is not in 2_backlog' do
      with_fixture_repo do |core, root|
        File.write("#{root}/features/1_icebox/TST-001-not-yet-committed.feature",
                   "# id: TST-001\n# status: icebox\n")
        silence_errors { expect { core.start('TST-001') }.to raise_error(SystemExit, /expected 2_backlog/) }
      end
    end
  end

  describe '#done' do
    it 'moves a backlog story to 4_done, updates status, and removes from backlog.md' do
      with_fixture_repo do |core, root|
        silence_output do
          core.create('bug', 'Some bug')
          core.commit('TST-001')
        end

        expect { core.done('TST-001') }.to output(/Done TST-001/).to_stdout

        expect(Dir.glob("#{root}/bugs/2_backlog/TST-001-*")).to be_empty
        done_files = Dir.glob("#{root}/bugs/4_done/TST-001-*")
        expect(done_files.size).to eq(1)

        content = File.read(done_files.first)
        expect(content).to include('status: done')

        backlog = File.read("#{root}/backlog.md")
        expect(backlog).not_to include('TST-001')
      end
    end

    it 'aborts when story is already done' do
      with_fixture_repo do |core, root|
        File.write("#{root}/bugs/4_done/TST-001-already-done.md",
                   "---\nid: TST-001\nstatus: done\n---\n")
        silence_errors { expect { core.done('TST-001') }.to raise_error(SystemExit, /already done/) }
      end
    end
  end

  describe '#set_stage' do
    it 'moves a story to a new stage and returns the new status' do
      with_fixture_repo do |core, root|
        silence_output { core.create('chore', 'Deploy infra') }
        result = core.set_stage('TST-001', '2_backlog')
        expect(result).to eq('backlog')
        expect(Dir.glob("#{root}/chores/2_backlog/TST-001-*")).not_to be_empty
        expect(Dir.glob("#{root}/chores/1_icebox/TST-001-*")).to be_empty
      end
    end

    it 'is a no-op when the story is already in the requested stage' do
      with_fixture_repo do |core, root|
        path = "#{root}/features/2_backlog/TST-001-existing.feature"
        File.write(path, "# id: TST-001\n# type: feature\n# status: backlog\n")
        expect(core.set_stage('TST-001', '2_backlog')).to eq('backlog')
        expect(File.exist?(path)).to be true
      end
    end

    it 'syncs backlog.md when moving out of 2_backlog' do
      with_fixture_repo do |core, root|
        silence_output do
          core.create('bug', 'Slow query')
          core.commit('TST-001')
        end
        expect(File.read("#{root}/backlog.md")).to include('TST-001')

        core.set_stage('TST-001', '4_done')
        expect(File.read("#{root}/backlog.md")).not_to include('TST-001')
      end
    end

    it 'moves a story through icebox → backlog → started → done' do
      with_fixture_repo do |core, root|
        silence_output { core.create('chore', 'Full workflow') }

        core.set_stage('TST-001', '2_backlog')
        expect(File.read("#{root}/backlog.md")).to include('TST-001')

        core.set_stage('TST-001', '3_started')
        expect(File.read("#{root}/backlog.md")).not_to include('TST-001')
        expect(Dir.glob("#{root}/chores/3_started/TST-001-*")).not_to be_empty

        core.set_stage('TST-001', '4_done')
        expect(Dir.glob("#{root}/chores/4_done/TST-001-*")).not_to be_empty
      end
    end

    it 'raises ArgumentError for an unknown stage' do
      with_fixture_repo do |core, _|
        expect { core.set_stage('TST-001', '5_limbo') }.to raise_error(ArgumentError, /Invalid stage/)
      end
    end

    it 'raises ArgumentError when the story does not exist' do
      with_fixture_repo do |core, _|
        expect { core.set_stage('TST-999', '2_backlog') }.to raise_error(ArgumentError, /not found/)
      end
    end
  end

  describe '#backlog_ids' do
    it 'returns IDs in order from backlog.md' do
      with_fixture_repo do |core, root|
        File.write("#{root}/backlog.md", "- TST-003 foo\n- TST-001 bar\n")
        expect(core.backlog_ids).to eq(%w[TST-003 TST-001])
      end
    end

    it 'matches correctly when namespace contains regex metacharacters' do
      with_fixture_repo(namespace: 'C+') do |core, root|
        File.write("#{root}/backlog.md", "- C+-001 fix something\n- C+-002 another\n")
        expect(core.backlog_ids).to eq(%w[C+-001 C+-002])
        expect(core.backlog_lines.size).to eq(2)
        expect(core.already_migrated?("#{root}/features/1_icebox/C+-001-fix.feature")).to be true
        expect(core.already_migrated?("#{root}/features/1_icebox/_template.feature")).to be false
      end
    end
  end

  describe '#backlog_remove' do
    it 'removes only the exact ID, not IDs it is a prefix of' do
      with_fixture_repo do |core, root|
        File.write("#{root}/backlog.md", "- TST-100 short one\n- TST-1000 long one\n")
        core.backlog_remove('TST-100')
        expect(File.read("#{root}/backlog.md")).to eq("- TST-1000 long one\n")
      end
    end

    it 'keeps lines that merely mention the ID in their title' do
      with_fixture_repo do |core, root|
        File.write("#{root}/backlog.md", "- TST-007 unblock TST-002 migration\n- TST-002 the migration\n")
        core.backlog_remove('TST-002')
        expect(File.read("#{root}/backlog.md")).to eq("- TST-007 unblock TST-002 migration\n")
      end
    end
  end

  describe '#backlog_reorder' do
    it 'reorders story lines while preserving non-story lines' do
      with_fixture_repo do |core, root|
        core.create_story('chore', 'Alpha', stage: '2_backlog')
        core.create_story('chore', 'Beta',  stage: '2_backlog')
        core.create_story('chore', 'Gamma', stage: '2_backlog')
        File.write("#{root}/backlog.md",
                   "# Backlog\n- TST-001 alpha\n- TST-002 beta\n- TST-003 gamma\n")
        core.backlog_reorder(%w[TST-003 TST-001 TST-002])
        lines = File.readlines("#{root}/backlog.md").map(&:chomp)
        expect(lines.first).to eq('# Backlog')
        story_lines = lines.grep(/TST-\d+/)
        expect(story_lines.map { |l| l[/TST-\d+/] }).to eq(%w[TST-003 TST-001 TST-002])
      end
    end

    it 'silently succeeds when backlog.md does not exist' do
      with_fixture_repo do |core, root|
        File.delete("#{root}/backlog.md")
        expect { core.backlog_reorder(%w[TST-001]) }.not_to raise_error
      end
    end
  end

  describe '#update_story' do
    it 'renames the file and updates the Feature line for a .feature story' do
      with_fixture_repo do |core, root|
        silence_output { core.create('feature', 'Old Title') }
        core.update_story('TST-001', title: 'New Title')

        expect(Dir.glob("#{root}/features/1_icebox/TST-001-old-title.*")).to be_empty
        new_files = Dir.glob("#{root}/features/1_icebox/TST-001-new-title.feature")
        expect(new_files.size).to eq(1)
        expect(File.read(new_files.first)).to include('Feature: New Title')
      end
    end

    it 'updates the body for a .md story without changing the filename' do
      with_fixture_repo do |core, root|
        silence_output { core.create('bug', 'Crash on login') }
        path_before = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").first
        core.update_story('TST-001', body: "Repro: open app.\n")
        expect(File.read(path_before)).to include('Repro: open app.')
      end
    end

    it 'handles titles containing backslash sequences without corruption' do
      with_fixture_repo do |core, root|
        silence_output { core.create('feature', 'Normal Title') }
        core.update_story('TST-001', title: 'Fix \\1 edge case')
        new_files = Dir.glob("#{root}/features/1_icebox/TST-001-*.feature")
        content = File.read(new_files.first)
        expect(content).to include('Feature: Fix \\1 edge case')
      end
    end

    it 'rewrites only the exact backlog line, not lines mentioning the ID' do
      with_fixture_repo do |core, root|
        File.write("#{root}/chores/2_backlog/TST-002-the-migration.md",
                   "---\nid: TST-002\ntype: chore\nstatus: backlog\n---\n\nbody\n")
        File.write("#{root}/backlog.md",
                   "- TST-007 unblock TST-002 migration\n- TST-002 the migration\n")
        core.update_story('TST-002', title: 'renamed migration')
        expect(File.read("#{root}/backlog.md"))
          .to eq("- TST-007 unblock TST-002 migration\n- TST-002 renamed migration\n")
      end
    end

    it 'syncs backlog.md when renaming a story in 2_backlog' do
      with_fixture_repo do |core, root|
        silence_output do
          core.create('chore', 'Old Name')
          core.commit('TST-001')
        end
        core.update_story('TST-001', title: 'New Name')
        backlog = File.read("#{root}/backlog.md")
        expect(backlog).to include('TST-001 New Name')
        expect(backlog).not_to include('Old Name')
      end
    end

    it 'renames the file and updates the body in a single call' do
      with_fixture_repo do |core, root|
        silence_output { core.create('bug', 'Old Title') }
        core.update_story('TST-001', title: 'New Title', body: "Repro: updated.\n")

        new_files = Dir.glob("#{root}/bugs/1_icebox/TST-001-new-title.md")
        expect(new_files.size).to eq(1)
        expect(File.read(new_files.first)).to include('Repro: updated.')
        expect(Dir.glob("#{root}/bugs/1_icebox/TST-001-old-title.md")).to be_empty
      end
    end

    it 'raises ArgumentError when story does not exist' do
      with_fixture_repo do |core, _|
        expect { core.update_story('TST-999', title: 'x') }.to raise_error(ArgumentError, /not found/)
      end
    end
  end

  describe '#create_story' do
    it 'creates a feature file and returns a story hash' do
      with_fixture_repo do |core, root|
        story = core.create_story('feature', 'API Feature')
        expect(story[:id]).to eq('TST-001')
        expect(story[:type]).to eq('feature')
        expect(story[:stage]).to eq('1_icebox')
        expect(Dir.glob("#{root}/features/1_icebox/TST-001-*.feature")).not_to be_empty
      end
    end

    it 'creates in a specified stage and adds to backlog.md when stage is 2_backlog' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Quick bug', stage: '2_backlog')
        expect(Dir.glob("#{root}/bugs/2_backlog/TST-001-*.md")).not_to be_empty
        expect(File.read("#{root}/backlog.md")).to include('TST-001')
      end
    end

    it 'falls back to the default feature template when the repo has none' do
      with_fixture_repo do |core, root|
        File.delete("#{root}/features/_template.feature")
        story = core.create_story('feature', 'No Template Feature')
        expect(story[:id]).to eq('TST-001')
        content = Dir.glob("#{root}/features/1_icebox/TST-001-*.feature").then { |f| File.read(f.first) }
        expect(content).to include('Feature: No Template Feature')
        expect(content).to include('Scenario:')
      end
    end

    it 'falls back to the default markdown template when the repo has none' do
      with_fixture_repo do |core, root|
        File.delete("#{root}/chores/_template.md")
        core.create_story('chore', 'No Template Chore')
        content = Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).to include('Title: No Template Chore')
        expect(content).to include('## Description')
      end
    end

    it 'raises ArgumentError for an unknown kind' do
      with_fixture_repo do |core, _|
        expect { core.create_story('epic', 'title') }.to raise_error(ArgumentError, /Unknown kind/)
      end
    end

    it 'raises ArgumentError for an unknown stage' do
      with_fixture_repo do |core, _|
        expect { core.create_story('bug', 'title', stage: '4_review') }.to raise_error(ArgumentError, /Unknown stage/)
      end
    end
  end

  describe '#delete_story' do
    it 'removes the story file' do
      with_fixture_repo do |core, root|
        story = core.create_story('chore', 'Disposable Chore')
        path = Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").first
        core.delete_story('TST-001')
        expect(File.exist?(path)).to be false
      end
    end

    it 'removes the story from backlog.md when deleting a backlog story' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Backlog Bug', stage: '2_backlog')
        expect(File.read("#{root}/backlog.md")).to include('TST-001')
        core.delete_story('TST-001')
        expect(File.read("#{root}/backlog.md")).not_to include('TST-001')
      end
    end

    it 'raises ArgumentError when story does not exist' do
      with_fixture_repo do |core, _|
        expect { core.delete_story('TST-999') }.to raise_error(ArgumentError, /not found/)
      end
    end
  end

  describe 'size (T-shirt points)' do
    it 'parse_story_file returns size from .md frontmatter' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/TST-001-sized-bug.md"
        File.write(path, "---\nid: TST-001\ntype: bug\nstatus: icebox\nsize: M\n---\n\nBody.\n")
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }
        story = core.parse_story_file(path, d)
        expect(story[:size]).to eq('M')
      end
    end

    it 'parse_story_file returns size from .feature frontmatter' do
      with_fixture_repo do |core, root|
        path = "#{root}/features/1_icebox/TST-001-sized-feature.feature"
        File.write(path, "# id: TST-001\n# type: feature\n# status: icebox\n# size: L\n\nFeature: Sized\n")
        d = { type: 'feature', ext: '.feature', stage: '1_icebox', dir: 'features' }
        story = core.parse_story_file(path, d)
        expect(story[:size]).to eq('L')
      end
    end

    it 'parse_story_file returns nil when size is absent or invalid' do
      with_fixture_repo do |core, root|
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }

        absent = "#{root}/bugs/1_icebox/TST-001-no-size.md"
        File.write(absent, "---\nid: TST-001\ntype: bug\nstatus: icebox\n---\n\nBody.\n")
        expect(core.parse_story_file(absent, d)[:size]).to be_nil

        invalid = "#{root}/bugs/1_icebox/TST-002-bad-size.md"
        File.write(invalid, "---\nid: TST-002\ntype: bug\nsize: XL\n---\n\nBody.\n")
        expect(core.parse_story_file(invalid, d)[:size]).to be_nil # XL is not S/M/L
      end
    end

    it 'create_story stores size in frontmatter' do
      with_fixture_repo do |core, root|
        story = core.create_story('bug', 'Sized Bug', size: 'S')
        expect(story[:size]).to eq('S')
        content = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).to include('size: S')
      end
    end

    it 'update_story sets size on a story without one' do
      with_fixture_repo do |core, root|
        core.create_story('chore', 'Unsized Chore')
        core.update_story('TST-001', size: 'L')
        content = Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).to include('size: L')
      end
    end

    it 'update_story changes an existing size' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Bug', size: 'S')
        core.update_story('TST-001', size: 'M')
        content = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).to include('size: M')
        expect(content).not_to include('size: S')
      end
    end

    it 'update_story clears size when passed an empty string' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Bug', size: 'M')
        core.update_story('TST-001', size: '')
        content = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).not_to include('size:')
      end
    end
  end

  describe 'blocked_by' do
    it 'parse_story_file returns blocked_by from .md frontmatter' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/TST-001-blocked-bug.md"
        File.write(path, "---\nid: TST-001\ntype: bug\nstatus: icebox\nblocked_by: TST-002, TST-003\n---\n\nBody.\n")
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }
        story = core.parse_story_file(path, d)
        expect(story[:blocked_by]).to eq(%w[TST-002 TST-003])
      end
    end

    it 'parse_story_file returns empty array when blocked_by is absent' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/TST-001-clear.md"
        File.write(path, "---\nid: TST-001\ntype: bug\nstatus: icebox\n---\n\nBody.\n")
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }
        expect(core.parse_story_file(path, d)[:blocked_by]).to eq([])
      end
    end

    it 'update_story sets blocked_by' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Blocked Bug')
        core.update_story('TST-001', blocked_by: %w[TST-002])
        content = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).to include('blocked_by: TST-002')
      end
    end

    it 'update_story clears blocked_by when passed an empty array' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Blocked Bug')
        core.update_story('TST-001', blocked_by: %w[TST-002])
        core.update_story('TST-001', blocked_by: [])
        content = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).not_to include('blocked_by')
      end
    end
  end

  describe 'linked_to' do
    it 'parse_story_file returns linked_to from .md frontmatter' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/TST-001-linked-bug.md"
        File.write(path, "---\nid: TST-001\ntype: bug\nstatus: icebox\nlinked_to: TST-002, TST-003\n---\n\nBody.\n")
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }
        story = core.parse_story_file(path, d)
        expect(story[:linked_to]).to eq(%w[TST-002 TST-003])
      end
    end

    it 'parse_story_file returns empty array when linked_to is absent' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/TST-001-clear.md"
        File.write(path, "---\nid: TST-001\ntype: bug\nstatus: icebox\n---\n\nBody.\n")
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }
        expect(core.parse_story_file(path, d)[:linked_to]).to eq([])
      end
    end

    it 'update_story sets linked_to' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Linked Bug')
        core.update_story('TST-001', linked_to: %w[TST-002])
        content = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).to include('linked_to: TST-002')
      end
    end

    it 'update_story clears linked_to when passed an empty array' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Linked Bug')
        core.update_story('TST-001', linked_to: %w[TST-002])
        core.update_story('TST-001', linked_to: [])
        content = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).not_to include('linked_to')
      end
    end

    it 'update_story sets blocked_by and linked_to independently in one story' do
      with_fixture_repo do |core, root|
        core.create_story('bug', 'Both')
        core.update_story('TST-001', blocked_by: %w[TST-002], linked_to: %w[TST-003])
        content = Dir.glob("#{root}/bugs/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).to include('blocked_by: TST-002')
        expect(content).to include('linked_to: TST-003')
      end
    end
  end

  describe '#with_reverse_links' do
    it 'derives blocks (inverse of blocked_by) and linked_from (inverse of linked_to)' do
      with_fixture_repo do |core, _root|
        core.create_story('bug', 'Alpha') # TST-001
        core.create_story('bug', 'Beta')  # TST-002
        core.update_story('TST-001', blocked_by: %w[TST-002], linked_to: %w[TST-002])

        by_id = core.with_reverse_links(core.all_stories).to_h { |s| [s[:id], s] }
        # TST-002 is on the far end of both relations TST-001 stored.
        expect(by_id['TST-002'][:blocks]).to eq(%w[TST-001])
        expect(by_id['TST-002'][:linked_from]).to eq(%w[TST-001])
        # The storing story has no reverse ends of its own.
        expect(by_id['TST-001'][:blocks]).to eq([])
        expect(by_id['TST-001'][:linked_from]).to eq([])
      end
    end

    it 'leaves both reverse fields empty when no story references another' do
      with_fixture_repo do |core, _root|
        core.create_story('bug', 'Lonely')
        s = core.with_reverse_links(core.all_stories).first
        expect(s[:blocks]).to eq([])
        expect(s[:linked_from]).to eq([])
      end
    end
  end

  describe 'assignee' do
    it 'parse_story_file returns assignee from frontmatter' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/TST-001-assigned.md"
        File.write(path, "---\nid: TST-001\ntype: bug\nstatus: icebox\nassignee: AB\n---\n\nBody.\n")
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }
        expect(core.parse_story_file(path, d)[:assignee]).to eq('AB')
      end
    end

    it 'parse_story_file returns nil when assignee is absent' do
      with_fixture_repo do |core, root|
        path = "#{root}/bugs/1_icebox/TST-001-unassigned.md"
        File.write(path, "---\nid: TST-001\ntype: bug\nstatus: icebox\n---\n\nBody.\n")
        d = { type: 'bug', ext: '.md', stage: '1_icebox', dir: 'bugs' }
        expect(core.parse_story_file(path, d)[:assignee]).to be_nil
      end
    end

    it 'update_story sets and clears assignee' do
      with_fixture_repo do |core, root|
        core.create_story('chore', 'Some chore')
        core.update_story('TST-001', assignee: 'JD')
        content = Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).to include('assignee: JD')

        core.update_story('TST-001', assignee: '')
        content = Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).not_to include('assignee')
      end
    end
  end

  describe 'subtasks' do
    def md_story(core, root, body)
      core.create_story('chore', 'With subtasks')
      core.update_story('TST-001', body: body)
      Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").first
    end

    describe 'parsing' do
      it 'reports done/total for checkbox lines in the body' do
        with_fixture_repo do |core, root|
          path = md_story(core, root, "Steps:\n\n- [ ] one\n- [x] two\n- [ ] three\n- [ ] four\n")
          d = { type: 'chore', ext: '.md', stage: '1_icebox', dir: 'chores' }
          expect(core.parse_story_file(path, d)[:subtasks]).to eq({ done: 1, total: 4 })
        end
      end

      it 'returns nil subtasks when the body has no checkboxes' do
        with_fixture_repo do |core, root|
          path = md_story(core, root, "Just prose, no checklist.\n")
          d = { type: 'chore', ext: '.md', stage: '1_icebox', dir: 'chores' }
          expect(core.parse_story_file(path, d)[:subtasks]).to be_nil
        end
      end

      it 'ignores checkbox lines inside fenced code blocks' do
        with_fixture_repo do |core, root|
          path = md_story(core, root, "- [ ] real\n```\n- [ ] fake\n```\n")
          d = { type: 'chore', ext: '.md', stage: '1_icebox', dir: 'chores' }
          expect(core.parse_story_file(path, d)[:subtasks]).to eq({ done: 0, total: 1 })
        end
      end

      it 'counts checkboxes in a .feature body, ignoring docstring content' do
        with_fixture_repo do |core, root|
          path = "#{root}/features/1_icebox/TST-001-feat.feature"
          File.write(path, <<~GHERKIN)
            # id: TST-001
            # type: feature
            # status: icebox

            Feature: Feat

            - [ ] task a
            - [x] task b

              Scenario: has a docstring
                Given a docstring
                  """
                  - [ ] not a task
                  """
          GHERKIN
          d = { type: 'feature', ext: '.feature', stage: '1_icebox', dir: 'features' }
          expect(core.parse_story_file(path, d)[:subtasks]).to eq({ done: 1, total: 2 })
        end
      end

      it 'survives a round-trip through update_story' do
        with_fixture_repo do |core, root|
          body = "- [ ] one\n- [x] two\n"
          md_story(core, root, body)
          expect(core.find_story('TST-001').then { |r| core.parse_story_file(r[:file], r) }[:body])
            .to include("- [ ] one\n- [x] two")
        end
      end
    end

    describe '#toggle_subtask' do
      it 'marks a subtask done, persists it, and returns the new counts' do
        with_fixture_repo do |core, root|
          path = md_story(core, root, "- [ ] one\n- [ ] two\n")
          counts = core.toggle_subtask('TST-001', 1, true)
          expect(counts).to eq({ done: 1, total: 2 })
          expect(File.read(path)).to include("- [ ] one\n- [x] two")
        end
      end

      it 'unchecks a done subtask' do
        with_fixture_repo do |core, root|
          path = md_story(core, root, "- [x] one\n")
          expect(core.toggle_subtask('TST-001', 0, false)).to eq({ done: 0, total: 1 })
          expect(File.read(path)).to include('- [ ] one')
        end
      end

      it "leaves the story's stage and frontmatter unchanged" do
        with_fixture_repo do |core, root|
          md_story(core, root, "- [ ] one\n")
          core.toggle_subtask('TST-001', 0, true)
          result = core.find_story('TST-001')
          expect(result[:stage]).to eq('1_icebox')
          expect(File.read(result[:file])).to include('status: icebox')
        end
      end

      it 'toggles subtasks in a .feature story' do
        with_fixture_repo do |core, root|
          path = "#{root}/features/1_icebox/TST-001-feat.feature"
          File.write(path, "# id: TST-001\n# type: feature\n# status: icebox\n\nFeature: Feat\n\n- [ ] task a\n")
          expect(core.toggle_subtask('TST-001', 0, true)).to eq({ done: 1, total: 1 })
          content = File.read(path)
          expect(content).to include('- [x] task a')
          expect(content).to include('# status: icebox')
        end
      end

      it 'raises ArgumentError for an unknown story' do
        with_fixture_repo do |core, _root|
          expect { core.toggle_subtask('TST-999', 0, true) }
            .to raise_error(ArgumentError, /not found/)
        end
      end

      it 'raises ArgumentError for an out-of-range index' do
        with_fixture_repo do |core, root|
          md_story(core, root, "- [ ] only\n")
          expect { core.toggle_subtask('TST-001', 5, true) }
            .to raise_error(ArgumentError, /no subtask at index/)
        end
      end

      it 'raises ArgumentError for a negative or non-integer index' do
        with_fixture_repo do |core, root|
          md_story(core, root, "- [ ] only\n")
          expect { core.toggle_subtask('TST-001', -1, true) }.to raise_error(ArgumentError)
          expect { core.toggle_subtask('TST-001', '0', true) }.to raise_error(ArgumentError)
        end
      end

      it 'raises ArgumentError when done is not a boolean' do
        with_fixture_repo do |core, root|
          md_story(core, root, "- [ ] only\n")
          expect { core.toggle_subtask('TST-001', 0, 'yes') }
            .to raise_error(ArgumentError, /true or false/)
        end
      end
    end
  end

  describe 'review-findings corruption guards' do
    describe 'BT-048: stage move with an existing destination' do
      it 'set_stage raises ArgumentError and leaves both copies intact' do
        with_fixture_repo do |core, root|
          File.write("#{root}/chores/2_backlog/TST-001-dupe.md",
                     "---\nid: TST-001\ntype: chore\nstatus: backlog\n---\n\nbacklog copy\n")
          File.write("#{root}/chores/4_done/TST-001-dupe.md",
                     "---\nid: TST-001\ntype: chore\nstatus: done\n---\n\ndone copy\n")

          expect { core.set_stage('TST-001', '4_done') }
            .to raise_error(ArgumentError, /already exists/)
          expect(File.read("#{root}/chores/4_done/TST-001-dupe.md")).to include('done copy')
          expect(File.read("#{root}/chores/2_backlog/TST-001-dupe.md")).to include('backlog copy')
        end
      end

      it 'done aborts cleanly instead of raising' do
        with_fixture_repo do |core, root|
          File.write("#{root}/chores/2_backlog/TST-001-dupe.md",
                     "---\nid: TST-001\ntype: chore\nstatus: backlog\n---\n")
          File.write("#{root}/chores/4_done/TST-001-dupe.md",
                     "---\nid: TST-001\ntype: chore\nstatus: done\n---\n")
          silence_errors { expect { core.done('TST-001') }.to raise_error(SystemExit, /already exists/) }
        end
      end
    end

    describe 'BT-050: combined title and body edit' do
      it 'applies the new title to the rebuilt body content of a .md story' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Old title')
          core.update_story('TST-001', title: 'New title', body: "Title: Old title\n\nnew body\n")
          content = File.read(Dir.glob("#{root}/chores/1_icebox/TST-001-new-title.md").first)
          expect(content).to include('Title: New title')
          expect(content).not_to include('Title: Old title')
          expect(content).to include('new body')
        end
      end

      it 'applies the new title to the rebuilt body content of a .feature story' do
        with_fixture_repo do |core, root|
          core.create_story('feature', 'Old feature')
          core.update_story('TST-001', title: 'New feature',
                                       body:  "Feature: Old feature\n\n  Scenario: pass\n")
          content = File.read(Dir.glob("#{root}/features/1_icebox/TST-001-new-feature.feature").first)
          expect(content).to include('Feature: New feature')
          expect(content).not_to include('Feature: Old feature')
        end
      end
    end

    describe 'BT-051: user input in sub replacements' do
      it 'writes titles containing backslash sequences literally on create' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Fix \& stuff')
          content = File.read(Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").first)
          expect(content).to include('Title: Fix \& stuff')
        end
      end

      it 'writes feature titles containing backslash sequences literally' do
        with_fixture_repo do |core, root|
          core.create_story('feature', 'Handle \0 bytes')
          content = File.read(Dir.glob("#{root}/features/1_icebox/TST-001-*.feature").first)
          expect(content).to include('Feature: Handle \0 bytes')
        end
      end

      it 'writes frontmatter values containing backslash sequences literally' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Some chore')
          core.update_story('TST-001', blocked_by: ['TST-9'])
          core.update_story('TST-001', blocked_by: ['TST-2\&'])
          content = File.read(Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").first)
          expect(content).to include('blocked_by: TST-2\&')
          expect(content.scan('blocked_by').size).to eq(1)
        end
      end
    end

    describe 'BT-052: newline injection into frontmatter and titles' do
      it 'rejects frontmatter values containing newlines' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Some chore')
          expect { core.update_story('TST-001', assignee: "AB\nstatus: done") }
            .to raise_error(ArgumentError, /newline/)
          expect { core.update_story('TST-001', blocked_by: ["TST-2\nstatus: done"]) }
            .to raise_error(ArgumentError, /newline/)
          content = File.read(Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").first)
          expect(content.scan(/^status:/).size).to eq(1)
        end
      end

      it 'rejects titles containing newlines on create and update' do
        with_fixture_repo do |core, _root|
          expect { core.create_story('chore', "sneaky\ntitle") }
            .to raise_error(ArgumentError, /newline/)
          story = core.create_story('chore', 'Legit chore')
          expect { core.update_story(story[:id], title: "new\nstatus: done") }
            .to raise_error(ArgumentError, /newline/)
        end
      end
    end
  end

  describe 'review-findings batch (BT-053…BT-060)' do
    describe 'BT-053: concurrent mutations' do
      it 'does not lose updates when two threads toggle different subtasks' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Concurrent')
          core.update_story('TST-001', body: "- [ ] one\n- [ ] two\n")
          path = Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").first

          5.times do
            core.update_story('TST-001', body: "- [ ] one\n- [ ] two\n")
            [0, 1].map { |i| Thread.new { core.toggle_subtask('TST-001', i, true) } }.each(&:join)
            content = File.read(path)
            expect(content).to include('- [x] one'), "lost toggle 0: #{content.inspect}"
            expect(content).to include('- [x] two'), "lost toggle 1: #{content.inspect}"
          end
        end
      end
    end

    describe 'BT-054: backlog_reorder with a stale order' do
      it 'keeps lines whose IDs are missing from the submitted order' do
        with_fixture_repo do |core, _root|
          core.create_story('chore', 'First',  stage: '2_backlog')
          core.create_story('chore', 'Second', stage: '2_backlog')
          core.create_story('chore', 'Third',  stage: '2_backlog')
          core.backlog_reorder(%w[TST-003 TST-001])
          expect(core.backlog_ids).to eq(%w[TST-003 TST-001 TST-002])
        end
      end
    end

    describe 'BT-055: malformed frontmatter resilience' do
      it 'parses a story with a Date-valued frontmatter field instead of raising' do
        with_fixture_repo do |core, root|
          path = "#{root}/chores/1_icebox/TST-001-dated.md"
          File.write(path, "---\nid: TST-001\ntype: chore\nstatus: icebox\ndue: 2026-08-09\n---\n\nbody\n")
          d = { type: 'chore', ext: '.md', stage: '1_icebox', dir: 'chores' }
          expect { core.parse_story_file(path, d) }.not_to raise_error
          expect(core.all_stories.map { |s| s[:id] }).to include('TST-001')
        end
      end

      it 'treats syntactically invalid frontmatter as empty instead of raising' do
        with_fixture_repo do |core, root|
          path = "#{root}/chores/1_icebox/TST-001-broken.md"
          File.write(path, "---\ntitle: foo: [unclosed\n---\n\nbody\n")
          d = { type: 'chore', ext: '.md', stage: '1_icebox', dir: 'chores' }
          story = silence_errors { core.parse_story_file(path, d) }
          expect(story[:id]).to eq('TST-001')
          expect(story[:size]).to be_nil
        end
      end
    end

    describe 'BT-056: corrupt .next-id' do
      it 'floors the counter above the highest existing story ID' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'First')
          core.create_story('chore', 'Second')
          File.write("#{root}/.next-id", "<<<<<<< HEAD\n12\n")
          story = core.create_story('chore', 'After corruption')
          expect(story[:id]).to eq('TST-003')
          expect(core.all_stories.map { |s| s[:id] }.tally.values).to all(eq(1))
        end
      end
    end

    describe 'BT-060: CRLF story files' do
      it 'parses CRLF frontmatter and updates status on stage moves' do
        with_fixture_repo do |core, root|
          path = "#{root}/chores/1_icebox/TST-001-windows.md"
          File.write(path, "---\r\nid: TST-001\r\ntype: chore\r\nstatus: icebox\r\n---\r\n\r\nbody line\r\n")
          d = { type: 'chore', ext: '.md', stage: '1_icebox', dir: 'chores' }
          story = core.parse_story_file(path, d)
          expect(story[:body]).to include('body line')
          expect(story[:body]).not_to include('id: TST-001')

          core.set_stage('TST-001', '2_backlog')
          moved = Dir.glob("#{root}/chores/2_backlog/TST-001-*.md").first
          expect(File.read(moved)).to include('status: backlog')
        end
      end

      it 'updates frontmatter fields on CRLF files' do
        with_fixture_repo do |core, root|
          path = "#{root}/chores/1_icebox/TST-001-windows.md"
          File.write(path, "---\r\nid: TST-001\r\ntype: chore\r\nstatus: icebox\r\n---\r\n\r\nbody\r\n")
          core.update_story('TST-001', assignee: 'AB')
          expect(File.read(path)).to include('assignee: AB')
        end
      end
    end
  end

  describe 'review-findings batch (BT-063)' do
    it 'finds and lists stories when tracker_root contains glob metacharacters' do
      with_fixture_repo do |_core, root|
        weird = File.join(root, '[old] projects')
        %w[features bugs chores].each do |kind|
          %w[1_icebox 2_backlog 3_started 4_done].each { |s| FileUtils.mkdir_p("#{weird}/#{kind}/#{s}") }
        end
        File.write("#{weird}/.next-id", '1')
        File.write("#{weird}/backlog.md", '')
        File.write("#{weird}/chores/1_icebox/TST-001-in-weird-dir.md",
                   "---\nid: TST-001\ntype: chore\nstatus: icebox\n---\n\nbody\n")

        config = BaconTracker::Configuration.new
        config.namespace = 'TST'
        config.tracker_root = weird
        core = BaconTracker::Core.new(config)

        expect(core.all_stories.map { |s| s[:id] }).to eq(['TST-001'])
        expect(core.find_story('TST-001')).not_to be_nil
        expect(core.max_story_id).to eq(1)
      end
    end

    it 'formats IDs literally when the namespace contains a percent sign' do
      config = BaconTracker::Configuration.new
      config.namespace = 'C%'
      expect(BaconTracker::Core.new(config).format_id(7)).to eq('C%-007')
    end

    it 'updates only the frontmatter status, never a matching body line' do
      with_fixture_repo do |core, root|
        path = "#{root}/chores/1_icebox/TST-001-statusful.md"
        File.write(path, "---\nid: TST-001\ntype: chore\nstatus: icebox\n---\n\nstatus: healthy\n")
        core.set_stage('TST-001', '2_backlog')
        content = File.read(Dir.glob("#{root}/chores/2_backlog/TST-001-*.md").first)
        expect(content).to include("status: backlog\n")
        expect(content).to include("status: healthy\n")
        expect(content.scan('status: backlog').size).to eq(1)
      end
    end

    it 'adds the status field on stage move when the frontmatter lacks one' do
      with_fixture_repo do |core, root|
        path = "#{root}/chores/1_icebox/TST-001-statusless.md"
        File.write(path, "---\nid: TST-001\ntype: chore\n---\n\nbody\n")
        core.set_stage('TST-001', '2_backlog')
        content = File.read(Dir.glob("#{root}/chores/2_backlog/TST-001-*.md").first)
        expect(content).to match(/^status: backlog$/)
      end
    end
  end

  describe 'deep-design follow-ups (BT-065)' do
    describe 'server-emitted subtask addresses' do
      it 'emits subtask_lines as body-line indices alongside the counts' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Addressed')
          core.update_story('TST-001', body: "intro\n\n- [ ] one\n  - [x] two\n\n```\n- [ ] fenced\n```\n")
          story = core.find_story('TST-001').then { |r| core.parse_story_file(r[:file], r) }
          expect(story[:subtask_lines]).to eq([2, 3])
          expect(story[:subtasks]).to eq({ done: 1, total: 2 })
        end
      end

      it 'emits nil subtask_lines when the body has no checklist' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Plain')
          core.update_story('TST-001', body: "prose only\n")
          story = core.find_story('TST-001').then { |r| core.parse_story_file(r[:file], r) }
          expect(story[:subtask_lines]).to be_nil
        end
      end
    end

    describe 'backlog self-healing' do
      it 'drops phantom lines and appends unlisted stories on reorder' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Listed one', stage: '2_backlog')
          core.create_story('chore', 'Unlisted', stage: '2_backlog')
          # simulate external drift: phantom line added, unlisted line removed
          File.write("#{root}/backlog.md", "- TST-001 listed one\n- TST-099 phantom\n")

          core.backlog_reorder(%w[TST-001])
          expect(core.backlog_ids).to eq(%w[TST-001 TST-002])
        end
      end

      it 'heals on stage moves too' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Mover')
          core.create_story('chore', 'Unlisted', stage: '2_backlog')
          File.write("#{root}/backlog.md", "- TST-099 phantom\n")

          core.set_stage('TST-001', '3_started')
          expect(core.backlog_ids).to eq(%w[TST-002])
        end
      end
    end

    describe '#status_drift' do
      it 'reports stories whose frontmatter status disagrees with their stage directory' do
        with_fixture_repo do |core, root|
          File.write("#{root}/chores/3_started/TST-001-drifted.md",
                     "---\nid: TST-001\ntype: chore\nstatus: backlog\n---\n\nbody\n")
          File.write("#{root}/chores/1_icebox/TST-002-fine.md",
                     "---\nid: TST-002\ntype: chore\nstatus: icebox\n---\n\nbody\n")
          drift = core.status_drift
          expect(drift.size).to eq(1)
          expect(drift.first).to include(id: 'TST-001', declared: 'backlog', actual: 'started')
        end
      end
    end

    describe '#relationship_findings' do
      # Write a chore at `stage` with optional blocked_by/linked_to frontmatter.
      def story(root, id, stage, blocked_by: nil, linked_to: nil)
        fm = ["id: #{id}", 'type: chore', "status: #{BaconTracker::STATUS_MAP[stage]}"]
        fm << "blocked_by: #{blocked_by}" if blocked_by
        fm << "linked_to: #{linked_to}" if linked_to
        File.write("#{root}/chores/#{stage}/#{id}-thing.md", "---\n#{fm.join("\n")}\n---\n\nbody\n")
      end

      it 'reports a blocker that is already done' do
        with_fixture_repo do |core, root|
          story(root, 'TST-001', '4_done')
          story(root, 'TST-002', '2_backlog', blocked_by: 'TST-001')

          expect(core.relationship_findings)
            .to contain_exactly(hash_including(kind: :stale_blocker, id: 'TST-002', ref: 'TST-001'))
        end
      end

      it 'reports a blocked_by naming a story that does not exist' do
        with_fixture_repo do |core, root|
          story(root, 'TST-002', '2_backlog', blocked_by: 'TST-999')

          expect(core.relationship_findings)
            .to contain_exactly(hash_including(kind: :dangling, id: 'TST-002', ref: 'TST-999', field: 'blocked_by'))
        end
      end

      it 'reports a linked_to naming a story that does not exist' do
        with_fixture_repo do |core, root|
          story(root, 'TST-002', '2_backlog', linked_to: 'TST-999')

          expect(core.relationship_findings)
            .to contain_exactly(hash_including(kind: :dangling, id: 'TST-002', ref: 'TST-999', field: 'linked_to'))
        end
      end

      # BT-024 waits on "sinatra-5.x" - blocking on something outside the
      # tracker is a real use of the field, not a dangling reference.
      it 'ignores blockers that are not story IDs for this namespace' do
        with_fixture_repo do |core, root|
          story(root, 'TST-002', '2_backlog', blocked_by: 'sinatra-5.x, rspec-4.x, OTHER-003')

          expect(core.relationship_findings).to be_empty
        end
      end

      it 'reports a two-story cycle once, not once per entry point' do
        with_fixture_repo do |core, root|
          story(root, 'TST-001', '2_backlog', blocked_by: 'TST-002')
          story(root, 'TST-002', '2_backlog', blocked_by: 'TST-001')

          cycles = core.relationship_findings.select { |f| f[:kind] == :cycle }
          expect(cycles.size).to eq(1)
          expect(cycles.first[:cycle]).to eq(%w[TST-001 TST-002])
        end
      end

      it 'reports a story that blocks itself' do
        with_fixture_repo do |core, root|
          story(root, 'TST-001', '2_backlog', blocked_by: 'TST-001')

          expect(core.relationship_findings)
            .to include(hash_including(kind: :cycle, cycle: %w[TST-001]))
        end
      end

      it 'notes a started story waiting on an unresolved blocker' do
        with_fixture_repo do |core, root|
          story(root, 'TST-001', '2_backlog')
          story(root, 'TST-002', '3_started', blocked_by: 'TST-001')

          expect(core.relationship_findings)
            .to contain_exactly(hash_including(kind: :started_while_blocked, id: 'TST-002', ref_stage: '2_backlog'))
        end
      end

      it 'classifies started-while-blocked as a warning, not an integrity failure' do
        expect(BaconTracker::Core::RELATIONSHIP_WARNINGS).to include(:started_while_blocked)
        expect(BaconTracker::Core::RELATIONSHIP_WARNINGS).not_to include(:stale_blocker, :dangling, :cycle)
      end

      # A started story whose blocker shipped isn't blocked - its frontmatter is
      # stale. Saying both would send the reader to fix the wrong thing.
      it 'prefers the stale-blocker finding over the started-while-blocked note' do
        with_fixture_repo do |core, root|
          story(root, 'TST-001', '4_done')
          story(root, 'TST-002', '3_started', blocked_by: 'TST-001')

          expect(core.relationship_findings)
            .to contain_exactly(hash_including(kind: :stale_blocker))
        end
      end

      # 4_done is append-only, so a done story's relationships are record, not
      # a to-do - otherwise lint gets louder with every story that ships.
      it 'does not report findings against a story that is already done' do
        with_fixture_repo do |core, root|
          story(root, 'TST-001', '4_done')
          story(root, 'TST-002', '4_done', blocked_by: 'TST-001, TST-999')

          expect(core.relationship_findings).to be_empty
        end
      end

      it 'says nothing about a graph where every reference resolves and no blocker is done' do
        with_fixture_repo do |core, root|
          story(root, 'TST-001', '2_backlog')
          story(root, 'TST-002', '1_icebox', blocked_by: 'TST-001', linked_to: 'TST-001')

          expect(core.relationship_findings).to be_empty
        end
      end
    end

    describe 'single-write update_story' do
      it 'leaves the file untouched when a later field validation fails' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Atomic')
          before = File.read(Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").first)
          expect { core.update_story('TST-001', title: 'New title', body: 'new body', size: 'XXL') }
            .to raise_error(ArgumentError, /size/)
          expect(File.read(Dir.glob("#{root}/chores/1_icebox/TST-001-*.md").first)).to eq(before)
        end
      end
    end

    describe '#git_first_commit_times' do
      it 'maps each file to its first-add timestamp, not its latest commit' do
        Dir.mktmpdir do |root|
          commit = lambda do |date, msg|
            system({ 'GIT_AUTHOR_DATE' => date, 'GIT_COMMITTER_DATE' => date },
                   'git', '-C', root, '-c', 'user.email=t@t', '-c', 'user.name=t',
                   'commit', '-q', '-m', msg)
          end
          system('git', '-C', root, 'init', '-q')
          File.write("#{root}/old.md", 'old')
          system('git', '-C', root, 'add', 'old.md'); commit.call('2020-01-01T00:00:00', 'add old')
          File.write("#{root}/new.md", 'new')
          system('git', '-C', root, 'add', 'new.md'); commit.call('2020-01-02T00:00:00', 'add new')
          # old.md is modified LATER than new.md was added - a "latest commit"
          # implementation would rank old after new; first-add must not.
          File.write("#{root}/old.md", 'old v2')
          system('git', '-C', root, 'add', 'old.md'); commit.call('2020-01-03T00:00:00', 'modify old')

          config = BaconTracker::Configuration.new
          config.namespace = 'TST'
          config.tracker_root = root
          times = BaconTracker::Core.new(config).git_first_commit_times
          expect(times.keys).to contain_exactly('old.md', 'new.md')
          expect(times['old.md']).to be < times['new.md'] # strict: distinct, first-add order
        end
      end

      it 'keys paths relative to tracker_root when it is a subdir of the repo (BT-105)' do
        Dir.mktmpdir do |repo|
          docs = File.join(repo, 'tracker')
          FileUtils.mkdir_p(docs)
          system('git', '-C', repo, 'init', '-q')
          File.write("#{docs}/old.md", 'old')
          system('git', '-C', repo, 'add', '.')
          system('git', '-C', repo, '-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-q', '-m', 'add old')

          config = BaconTracker::Configuration.new
          config.namespace = 'TST'
          config.tracker_root = docs
          times = BaconTracker::Core.new(config).git_first_commit_times
          expect(times.keys).to include('old.md') # not "tracker/old.md"
        end
      end
    end
  end

  describe '#stats' do
    it 'returns counts by stage and next_task from the top backlog item' do
      with_fixture_repo do |core, root|
        silence_output do
          core.create('feature', 'Alpha')
          core.create('bug', 'Beta')
          core.commit('TST-001')
        end
        s = core.stats
        expect(s[:backlog]).to eq(1)
        expect(s[:icebox]).to eq(1)
        expect(s[:started]).to eq(0)
        expect(s[:done]).to eq(0)
        expect(s[:next_task]).to eq('alpha')
      end
    end

    it 'returns progress_pct as done/total * 100 rounded' do
      with_fixture_repo do |core, root|
        silence_output do
          core.create('chore', 'Done one')
          core.commit('TST-001')
          core.done('TST-001')
          core.create('chore', 'In backlog')
          core.commit('TST-002')
        end
        s = core.stats
        expect(s[:progress_pct]).to eq(50)
      end
    end

    it 'returns progress_pct: 0 and next_task: nil when no stories exist' do
      with_fixture_repo do |core, _|
        s = core.stats
        expect(s[:progress_pct]).to eq(0)
        expect(s[:next_task]).to be_nil
        expect(s[:total]).to eq(0)
      end
    end
  end

  describe '#duplicate_id_stages' do
    it 'returns empty hash when no IDs are duplicated' do
      with_fixture_repo do |core, _|
        expect(core.duplicate_id_stages).to eq({})
      end
    end

    it 'returns the offending ID with both stage paths when an ID appears in two stages' do
      with_fixture_repo do |core, root|
        File.write("#{root}/features/1_icebox/TST-001-thing.feature", "# id: TST-001\n")
        File.write("#{root}/features/2_backlog/TST-001-thing.feature", "# id: TST-001\n")
        dups = core.duplicate_id_stages
        expect(dups.keys).to include('TST-001')
        expect(dups['TST-001'].size).to eq(2)
      end
    end
  end

  describe '#max_story_id' do
    it 'returns 0 for an empty tree' do
      with_fixture_repo do |core, _|
        expect(core.max_story_id).to eq(0)
      end
    end

    it 'returns the highest story number across all types and stages' do
      with_fixture_repo do |core, root|
        File.write("#{root}/features/1_icebox/TST-003-a.feature", "# id: TST-003\n")
        File.write("#{root}/bugs/4_done/TST-012-b.md", "---\nid: TST-012\n---\n")
        File.write("#{root}/chores/2_backlog/TST-007-c.md", "---\nid: TST-007\n---\n")
        expect(core.max_story_id).to eq(12)
      end
    end

    it 'ignores templates and files outside the namespace' do
      with_fixture_repo do |core, root|
        File.write("#{root}/features/1_icebox/TST-002-a.feature", "# id: TST-002\n")
        File.write("#{root}/chores/1_icebox/OTHER-099-x.md", '')
        expect(core.max_story_id).to eq(2)
      end
    end
  end

  describe '#humanize_slug' do
    it 'strips ID prefix and converts dashes to spaces' do
      config = BaconTracker::Configuration.new
      config.namespace = 'TST'
      core = BaconTracker::Core.new(config)
      expect(core.humanize_slug('TST-001-my-feature.feature')).to eq('my feature')
      expect(core.humanize_slug('TST-042-fix-the-login-bug.md')).to eq('fix the login bug')
    end
  end
end

RSpec.describe BaconTracker::Configuration do
  # BT-129 / BT-ADR-0016: the attribute named the *tracker's* story directory,
  # which stopped being defensible once a docs root existed alongside it.
  # The rename freed `docs_root` for its literal meaning. It exists again, and
  # now names the docs tree - never the tracker's story directory (BT-136).
  it 'keeps the tracker root and the docs root as separate things' do
    config = described_class.new
    config.tracker_root = '/tmp/x/tracker'
    config.docs_root    = '/tmp/x/docs'

    expect(config.tracker_root).to eq('/tmp/x/tracker')
    expect(config.docs_root).to eq('/tmp/x/docs')
    expect(config.next_id_path).to start_with('/tmp/x/tracker')
  end

  it 'lists only the roots that are set, so an unset one cannot widen a scope check' do
    config = described_class.new
    config.tracker_root = '/tmp/x/tracker'

    expect(config.roots).to eq(['/tmp/x/tracker'])

    config.docs_root = '/tmp/x/docs'
    expect(config.roots).to contain_exactly('/tmp/x/tracker', '/tmp/x/docs')
  end

  it "derives the tracker's own files from tracker_root" do
    config = described_class.new
    config.tracker_root = '/tmp/x/tracker'

    expect(config.next_id_path).to eq('/tmp/x/tracker/.next-id')
    expect(config.backlog_path).to eq('/tmp/x/tracker/backlog.md')
  end

  # BT-167: the ADR lint needs a root of its own. It is not derivable from
  # tracker_root - a project's stories can live in a parent repo while its
  # decisions live in its own, so the two genuinely differ.
  it 'carries a decisions root independent of the tracker root' do
    config = described_class.new
    config.tracker_root   = '/tmp/x/tracker'
    config.decisions_root = '/tmp/x/docs/decisions'

    expect(config.decisions_root).to eq('/tmp/x/docs/decisions')
    expect(config.decisions_next_id_path).to eq('/tmp/x/docs/decisions/.next-id')
    expect(config.proposed_path).to eq('/tmp/x/docs/decisions/proposed.md')
  end

  it 'leaves the decisions root nil when unset' do
    expect(described_class.new.decisions_root).to be_nil
  end
end

RSpec.describe 'decisions fixture' do
  it 'is absent unless asked for' do
    with_fixture_repo do |core, root|
      expect(core.config.decisions_root).to be_nil
      expect(Dir.exist?(File.join(root, 'docs', 'decisions'))).to be(false)
    end
  end

  it 'builds the five status directories and the tracked-subtree files' do
    with_fixture_repo(decisions: true) do |core, _root|
      d = core.config.decisions_root
      BaconTracker::STATUSES.each { |s| expect(Dir.exist?(File.join(d, s))).to be(true) }
      expect(File.read(File.join(d, '.next-id'))).to eq('1')
      expect(File.exist?(File.join(d, '_template.md'))).to be(true)
      expect(File.exist?(File.join(d, 'proposed.md'))).to be(true)
    end
  end

  it 'writes a record into the directory its status names' do
    with_fixture_repo(decisions: true) do |core, _root|
      path = write_decision(core, status: 'accepted', id: 7, slug: 'pick-a-thing')
      expect(path).to end_with('accepted/TST-ADR-0007-pick-a-thing.md')
      expect(File.read(path)).to include('status: accepted')
    end
  end
end
