require 'spec_helper'

RSpec.describe 'decision lint (BT-ADR-0014)' do
  def kinds(core)  = core.decision_findings.map { |f| f[:kind] }
  def fails(core)  = core.decision_findings.select { |f| f[:severity] == :failure }
  def warns(core)  = core.decision_findings.select { |f| f[:severity] == :warning }

  it 'is clean on a well-formed corpus' do
    with_fixture_repo(decisions: true) do |core, _|
      write_decision(core, status: 'accepted', id: 1)
      File.write(core.config.decisions_next_id_path, '2')
      expect(core.decision_findings).to be_empty
    end
  end

  it 'reports no records at all when the decisions root is unset' do
    with_fixture_repo do |core, _|
      expect(core.decision_findings).to be_empty
    end
  end

  describe 'failures' do
    it 'flags a record with no frontmatter, and suppresses the per-key checks' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1, frontmatter: '')
        File.write(core.config.decisions_next_id_path, '2')
        expect(kinds(core)).to eq(%w[no-frontmatter])
      end
    end

    it 'flags a status outside the five' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1,
                       frontmatter: "---\nstatus: intermediate\ndate: 2026-09-14\n---\n")
        File.write(core.config.decisions_next_id_path, '2')
        expect(kinds(core)).to include('unknown-status')
      end
    end

    it 'flags a status that disagrees with its directory' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1,
                       frontmatter: "---\nstatus: proposed\ndate: 2026-09-14\n---\n")
        File.write(core.config.decisions_next_id_path, '2')
        expect(kinds(core)).to include('status-drift')
      end
    end

    it 'flags a date that is not ISO-8601' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1,
                       frontmatter: "---\nstatus: accepted\ndate: 14.09.2026\n---\n")
        File.write(core.config.decisions_next_id_path, '2')
        expect(kinds(core)).to include('bad-date')
      end
    end

    it 'flags a duplicate number across status directories' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1, slug: 'one')
        write_decision(core, status: 'rejected', id: 1, slug: 'two')
        File.write(core.config.decisions_next_id_path, '2')
        expect(kinds(core)).to include('duplicate-id')
      end
    end

    it 'flags an own-namespace supersedes that does not resolve' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1,
                       frontmatter: "---\nstatus: accepted\ndate: 2026-09-14\nsupersedes: [TST-ADR-0099]\n---\n")
        File.write(core.config.decisions_next_id_path, '2')
        expect(kinds(core)).to include('dangling-ref')
      end
    end

    it 'flags an asymmetric own-namespace supersession' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'superseded', id: 1, slug: 'old',
                       frontmatter: "---\nstatus: superseded\ndate: 2026-09-14\nsuperseded_by: [TST-ADR-0002]\n---\n")
        write_decision(core, status: 'accepted', id: 2, slug: 'new')
        File.write(core.config.decisions_next_id_path, '3')
        expect(kinds(core)).to include('asymmetric-supersession')
      end
    end

    it 'flags a .next-id at or below the highest id on disk' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 4)
        File.write(core.config.decisions_next_id_path, '4')
        expect(kinds(core)).to include('stale-next-id')
      end
    end

    it 'flags proposed.md drift in both directions' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'proposed', id: 1, slug: 'unlisted')
        File.write(core.config.proposed_path, "# Decisions\n\n- TST-ADR-0099 - ghost\n")
        File.write(core.config.decisions_next_id_path, '2')
        expect(kinds(core)).to include('unlisted', 'phantom-entry')
      end
    end
  end

  describe 'warnings' do
    it 'warns on a .md in a status directory that is not a record' do
      with_fixture_repo(decisions: true) do |core, _|
        File.write(File.join(core.config.decisions_root, 'accepted', 'notes.md'), "# stray\n")
        expect(warns(core).map { |f| f[:kind] }).to include('not-a-record')
        expect(fails(core)).to be_empty
      end
    end

    it 'warns when superseded carries an empty superseded_by' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'superseded', id: 1)
        File.write(core.config.decisions_next_id_path, '2')
        expect(warns(core).map { |f| f[:kind] }).to include('no-successor')
      end
    end

    it 'warns when the ## Status prose contradicts the directory' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1, body: "## Status\n\nProposed\n")
        File.write(core.config.decisions_next_id_path, '2')
        expect(warns(core).map { |f| f[:kind] }).to include('prose-drift')
      end
    end
  end

  describe 'cross-namespace ids are unchecked (BT-ADR-0013)' do
    it 'ignores supersedes, stories and canonical from another namespace' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1,
          frontmatter: "---\nstatus: accepted\ndate: 2026-09-14\n" \
                       "supersedes: [OTH-ADR-0009]\nstories: [TST-999]\ncanonical: OTH-ADR-0021\n---\n")
        File.write(core.config.decisions_next_id_path, '2')
        expect(core.decision_findings).to be_empty
      end
    end
  end
end

RSpec.describe 'decision primitives (BT-154)' do
  it 'issues four-digit ids carrying the ADR token' do
    with_fixture_repo(decisions: true) do |core, _|
      expect(core.format_decision_id(7)).to eq('TST-ADR-0007')
      expect(core.consume_decision_id).to eq(1)
      expect(core.consume_decision_id).to eq(2)
    end
  end

  it 'floors the decision counter against decisions, never against stories' do
    with_fixture_repo(decisions: true) do |core, _|
      core.consume_id # story counter -> 2
      write_decision(core, status: 'accepted', id: 40)
      File.write(core.config.decisions_next_id_path, '3') # stale
      expect(core.consume_decision_id).to eq(41)
    end
  end

  it 'heals proposed.md from the directory while keeping order and prose' do
    with_fixture_repo(decisions: true) do |core, _|
      write_decision(core, status: 'proposed', id: 2, slug: 'second')
      write_decision(core, status: 'proposed', id: 1, slug: 'first')
      File.write(core.config.proposed_path,
                 "# Decisions to make, in order\n\n- TST-ADR-0002 - second\n- TST-ADR-0099 - ghost\n")
      core.heal_proposed!
      out = File.read(core.config.proposed_path)
      expect(out).to start_with("# Decisions to make, in order\n")
      expect(out).not_to include('TST-ADR-0099')
      expect(out.index('TST-ADR-0002')).to be < out.index('TST-ADR-0001')
    end
  end
end

RSpec.describe 'Core#docs_stats (BT-138)' do
  it 'counts prose pages, decisions, and proposed decisions' do
    with_fixture_repo(decisions: true) do |core, root|
      docs = File.dirname(core.config.decisions_root)
      FileUtils.mkdir_p(File.join(docs, 'guides'))
      File.write(File.join(docs, 'guides', 'setup.md'), "# Setup\n")
      File.write(File.join(docs, 'notes.txt'), "loose\n")
      File.write(File.join(docs, 'diagram.png'), '')          # not a page
      File.write(File.join(docs, '_draft.md'), "hidden\n")    # underscore-hidden
      File.write(File.join(docs, '.hidden.md'), "dot\n")      # dotfile
      write_decision(core, status: 'accepted', id: 1)
      write_decision(core, status: 'proposed', id: 2)

      core.config.docs_root = docs
      s = core.docs_stats
      expect(s[:pages]).to eq(2) # setup.md + notes.txt
      expect(s[:decisions]).to eq(2)
      expect(s[:proposed]).to eq(1)
    end
  end

  it 'does not count decision records, proposed.md, or the template as pages' do
    with_fixture_repo(decisions: true) do |core, _|
      core.config.docs_root = File.dirname(core.config.decisions_root)
      write_decision(core, status: 'accepted', id: 1)
      expect(core.docs_stats[:pages]).to eq(0)
    end
  end

  it 'does not count the tracker tree when it sits inside the docs tree' do
    with_fixture_repo(decisions: true) do |core, root|
      docs = File.join(root, 'docs-combined')
      FileUtils.mkdir_p(File.join(docs, 'tracker'))
      File.write(File.join(docs, 'tracker', 'backlog.md'), "- TST-001 x\n")
      File.write(File.join(docs, 'page.md'), "# P\n")
      core.config.docs_root    = docs
      core.config.tracker_root = File.join(docs, 'tracker')
      expect(core.docs_stats[:pages]).to eq(1)
    end
  end

  it 'is all zeros with no docs root' do
    with_fixture_repo do |core, _|
      expect(core.docs_stats).to eq(pages: 0, decisions: 0, proposed: 0)
    end
  end
end
