require 'spec_helper'

# BT-135 / BT-ADR-0017: one primitive, four surfaces. The rules live in
# Core#set_status so the board, the API, the Rake tasks and the command inherit
# them without knowing why.
RSpec.describe 'Core#set_status' do
  def record_for(core, id)
    core.decisions.find { |r| r[:id] == "TST-ADR-#{format('%04d', id)}" }
  end

  describe 'the verbs' do
    it 'accept: moves the file, mirrors the status, and sets date to today' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'proposed', id: 1,
                       frontmatter: "---\nstatus: proposed\ndate: 2026-01-05\n---\n",
                       body: "## Status\n\nProposed\n\nContext here.")
        core.heal_proposed!
        expect(File.read(core.config.proposed_path)).to include('TST-ADR-0001')

        core.set_status('TST-ADR-0001', 'accepted')

        r = record_for(core, 1)
        expect(r[:stage]).to eq('accepted')
        expect(r[:declared]).to eq('accepted')
        expect(r[:date]).to eq(Date.today.iso8601)
        # the prose mirror is updated too, so a transition never plants a warning
        expect(r[:body]).to include("## Status\n\nAccepted")
        expect(File.read(core.config.proposed_path)).not_to include('TST-ADR-0001')
        expect(core.decision_findings).to be_empty
      end
    end

    it 'reject: same shape, terminal' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'proposed', id: 1)
        core.set_status('TST-ADR-0001', 'rejected')
        expect(record_for(core, 1)[:stage]).to eq('rejected')
        expect(record_for(core, 1)[:date]).to eq(Date.today.iso8601)
      end
    end

    it 'deprecate: moves the file but never the date' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1,
                       frontmatter: "---\nstatus: accepted\ndate: 2026-01-05\n---\n")
        core.set_status('TST-ADR-0001', 'deprecated')
        r = record_for(core, 1)
        expect(r[:stage]).to eq('deprecated')
        expect(r[:date]).to eq('2026-01-05')
      end
    end
  end

  describe 'supersede' do
    it 'requires a target - a missing one raises before anything is written' do
      with_fixture_repo(decisions: true) do |core, _|
        path = write_decision(core, status: 'accepted', id: 1)
        before = File.read(path)
        expect { core.set_status('TST-ADR-0001', 'superseded') }
          .to raise_error(ArgumentError, /superseded_by/)
        expect(File.read(path)).to eq(before)
      end
    end

    it 'writes both sides of an in-namespace pair' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1, slug: 'old',
                       frontmatter: "---\nstatus: accepted\ndate: 2026-01-05\n---\n")
        write_decision(core, status: 'accepted', id: 2, slug: 'new')

        core.set_status('TST-ADR-0001', 'superseded', superseded_by: 'TST-ADR-0002')

        old = record_for(core, 1)
        new = record_for(core, 2)
        expect(old[:stage]).to eq('superseded')
        expect(old[:fm]['superseded_by']).to include('TST-ADR-0002')
        expect(new[:fm]['supersedes']).to include('TST-ADR-0001')
        expect(old[:date]).to eq('2026-01-05') # supersede never moves date
        expect(core.decision_findings).to be_empty
      end
    end

    it 'raises on an unresolvable in-namespace target, modifying neither record' do
      with_fixture_repo(decisions: true) do |core, _|
        path = write_decision(core, status: 'accepted', id: 1)
        before = File.read(path)
        expect { core.set_status('TST-ADR-0001', 'superseded', superseded_by: 'TST-ADR-0099') }
          .to raise_error(ArgumentError, /TST-ADR-0099/)
        expect(File.read(path)).to eq(before)
      end
    end

    it 'writes only the local side for a cross-namespace target, and says so' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1)
        result = core.set_status('TST-ADR-0001', 'superseded', superseded_by: 'OTH-ADR-0021')
        expect(record_for(core, 1)[:fm]['superseded_by']).to include('OTH-ADR-0021')
        expect(result[:external]).to include('OTH-ADR-0021')
        expect(core.decision_findings).to be_empty # cross-namespace is unchecked
      end
    end
  end

  describe 'the graph is forward-only' do
    it 'refuses every move back to proposed, and any move out of a terminal status' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'accepted', id: 1)
        write_decision(core, status: 'rejected', id: 2)
        expect { core.set_status('TST-ADR-0001', 'proposed') }
          .to raise_error(ArgumentError, /supersede/i)
        expect { core.set_status('TST-ADR-0002', 'accepted') }
          .to raise_error(ArgumentError)
      end
    end

    it 'refuses skipping straight from proposed to deprecated or superseded' do
      with_fixture_repo(decisions: true) do |core, _|
        write_decision(core, status: 'proposed', id: 1)
        expect { core.set_status('TST-ADR-0001', 'deprecated') }.to raise_error(ArgumentError)
      end
    end

    it 'raises on an unknown record or status - never aborts (BT-ADR-0005)' do
      with_fixture_repo(decisions: true) do |core, _|
        expect { core.set_status('TST-ADR-0042', 'accepted') }.to raise_error(ArgumentError, /not found/)
        write_decision(core, status: 'proposed', id: 1)
        expect { core.set_status('TST-ADR-0001', 'shipped') }.to raise_error(ArgumentError, /shipped/)
      end
    end
  end
end

RSpec.describe 'Core#create_decision (BT-146)' do
  it 'creates a lint-clean proposed record from the template' do
    with_fixture_repo(decisions: true) do |core, _|
      path = core.create_decision('Adopt a queue')

      expect(path).to end_with('proposed/TST-ADR-0001-adopt-a-queue.md')
      content = File.read(path)
      expect(content).to include('status: proposed')
      expect(content).to include("date: #{Date.today.iso8601}")
      expect(content).to include('# Adopt a queue')
      expect(content).not_to include('Name the decision')
      expect(File.read(core.config.proposed_path)).to include('TST-ADR-0001 - Adopt a queue')
      expect(core.decision_findings).to be_empty
    end
  end

  it 'never reuses an id, even against a stale counter' do
    with_fixture_repo(decisions: true) do |core, _|
      write_decision(core, status: 'accepted', id: 7)
      File.write(core.config.decisions_next_id_path, '2') # stale
      first  = core.create_decision('One')
      second = core.create_decision('Two')
      expect(first).to include('TST-ADR-0008')
      expect(second).to include('TST-ADR-0009')
    end
  end

  it 'still works without a template, from the built-in default' do
    with_fixture_repo(decisions: true) do |core, _|
      FileUtils.rm(File.join(core.config.decisions_root, '_template.md'))
      path = core.create_decision('Bare')
      expect(File.read(path)).to include('status: proposed').and include('# Bare')
      expect(core.decision_findings).to be_empty
    end
  end

  it 'raises on a blank title - web-reachable, never aborts' do
    with_fixture_repo(decisions: true) do |core, _|
      expect { core.create_decision('  ') }.to raise_error(ArgumentError, /title/i)
    end
  end
end

RSpec.describe 'proposed ordering (BT-147)' do
  it 'orders the proposed column by proposed.md, position being the priority' do
    with_fixture_repo(decisions: true) do |core, _|
      write_decision(core, status: 'proposed', id: 1, slug: 'first')
      write_decision(core, status: 'proposed', id: 2, slug: 'second')
      File.write(core.config.proposed_path,
                 "# Decisions to make, in order\n\n- TST-ADR-0002 - Second\n- TST-ADR-0001 - First\n")
      ids = core.decisions_board.select { |r| r[:status] == 'proposed' }.map { |r| r[:id] }
      expect(ids).to eq(%w[TST-ADR-0002 TST-ADR-0001])
    end
  end

  it 'rewrites proposed.md in the new order, records untouched, prose kept' do
    with_fixture_repo(decisions: true) do |core, _|
      a = write_decision(core, status: 'proposed', id: 1, slug: 'first')
      write_decision(core, status: 'proposed', id: 2, slug: 'second')
      core.heal_proposed!
      before_record = File.read(a)

      core.proposed_reorder(%w[TST-ADR-0002 TST-ADR-0001])

      out = File.read(core.config.proposed_path)
      expect(out).to start_with('# Decisions to make, in order')
      expect(out.index('TST-ADR-0002')).to be < out.index('TST-ADR-0001')
      expect(File.read(a)).to eq(before_record)
    end
  end

  it 'keeps entries a stale client did not know about' do
    with_fixture_repo(decisions: true) do |core, _|
      write_decision(core, status: 'proposed', id: 1, slug: 'one')
      write_decision(core, status: 'proposed', id: 2, slug: 'two')
      write_decision(core, status: 'proposed', id: 3, slug: 'three')
      core.heal_proposed!
      core.proposed_reorder(%w[TST-ADR-0002 TST-ADR-0001])
      out = File.read(core.config.proposed_path)
      expect(out).to include('TST-ADR-0003')
      expect(out.index('TST-ADR-0001')).to be < out.index('TST-ADR-0003')
    end
  end
end
