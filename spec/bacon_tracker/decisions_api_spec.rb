require 'spec_helper'
require 'rack/test'
require 'bacon_tracker/server'

RSpec.describe 'PUT /api/decisions/:id/status' do
  include Rack::Test::Methods
  def app = BaconTracker::Server

  around do |example|
    with_fixture_repo(decisions: true) do |core, _root|
      @core = core
      BaconTracker::Server.boot(core.config)
      example.run
    end
  end

  before { header 'Host', 'localhost'; header 'Content-Type', 'application/json' }

  def transition(id, body) = put("/api/decisions/#{id}/status", body.to_json)

  it 'accepts a proposed decision' do
    write_decision(@core, status: 'proposed', id: 1)
    res = transition('TST-ADR-0001', status: 'accepted')
    expect(res.status).to eq(200)
    expect(JSON.parse(res.body)['status']).to eq('accepted')
    expect(@core.decisions.first[:stage]).to eq('accepted')
  end

  it 'is a 400 when supersede has no target - never a partial write' do
    path = write_decision(@core, status: 'accepted', id: 1)
    before = File.read(path)
    res = transition('TST-ADR-0001', status: 'superseded')
    expect(res.status).to eq(400)
    expect(JSON.parse(res.body)['error']).to match(/superseded_by/)
    expect(File.read(path)).to eq(before)
  end

  it 'is a 400 for an unknown record, an invalid status, and a backwards move' do
    expect(transition('TST-ADR-0042', status: 'accepted').status).to eq(400)
    write_decision(@core, status: 'accepted', id: 1)
    expect(transition('TST-ADR-0001', status: 'shipped').status).to eq(400)
    expect(transition('TST-ADR-0001', status: 'proposed').status).to eq(400)
  end

  it 'reports the unwritten side of a cross-namespace supersession' do
    write_decision(@core, status: 'accepted', id: 1)
    res = transition('TST-ADR-0001', status: 'superseded', superseded_by: 'OTH-ADR-0021')
    expect(res.status).to eq(200)
    expect(JSON.parse(res.body)['external']).to eq(['OTH-ADR-0021'])
  end
end

RSpec.describe 'story ↔ decision citations (BT-148)' do
  include Rack::Test::Methods
  def app = BaconTracker::Server

  before { header 'Host', 'localhost' }

  it 'attaches the citing decisions to each story on the board GET' do
    with_fixture_repo(decisions: true) do |core, _|
      core.create_story('chore', 'Wire the thing') # TST-001
      write_decision(core, status: 'accepted', id: 4,
                     frontmatter: "---\nstatus: accepted\ndate: 2026-09-14\nstories: [TST-001, OTH-9]\n---\n")
      BaconTracker::Server.boot(core.config)
      stories = JSON.parse(get('/api/stories').body).values.flatten
      story = stories.find { |st| st['id'] == 'TST-001' }
      expect(story['decisions']).to eq(['TST-ADR-0004'])
    end
  end
end
