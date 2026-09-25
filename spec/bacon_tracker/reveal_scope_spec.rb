require 'spec_helper'
require 'rack/test'
require 'bacon_tracker/server'

# BT-136 / BT-085. The reveal endpoint spawns `open -R` on a caller-supplied
# path, so its scope check is the only thing between the browser and the rest of
# the filesystem. BT-ADR-0016 gives a project a second root, which means the
# check must widen without loosening.
RSpec.describe 'POST /api/reveal scope' do
  include Rack::Test::Methods
  def app = BaconTracker::Server

  around do |example|
    Dir.mktmpdir do |base|
      @base = base
      @tracker   = File.join(base, 'proj', 'tracker')
      @docs      = File.join(base, 'proj', 'docs')
      @decisions = File.join(@docs, 'decisions')
      [@tracker, @decisions].each { |d| FileUtils.mkdir_p(d) }
      # A sibling whose name shares the tracker root's prefix - the classic
      # start_with? hole.
      FileUtils.mkdir_p("#{@tracker}-evil")

      config = BaconTracker::Configuration.new
      config.namespace      = 'TST'
      config.tracker_root   = @tracker
      config.docs_root      = @docs
      config.decisions_root = @decisions
      BaconTracker::Server.boot(config)
      example.run
    end
  end

  before { header 'Host', 'localhost'; header 'Content-Type', 'application/json' }

  def reveal(path) = post('/api/reveal', { path: path }.to_json)

  it 'allows a path inside the tracker root' do
    expect(reveal(File.join(@tracker, 'backlog.md')).status).to eq(200)
  end

  it 'allows a path inside the docs root' do
    expect(reveal(File.join(@docs, 'guide.md')).status).to eq(200)
  end

  it 'allows a path inside the decisions root' do
    expect(reveal(File.join(@decisions, 'accepted')).status).to eq(200)
  end

  it 'allows a root itself' do
    expect(reveal(@tracker).status).to eq(200)
  end

  it 'refuses a path outside every configured root' do
    expect(reveal(File.join(@base, 'elsewhere', 'secret.md')).status).to eq(400)
  end

  it 'refuses a traversal that climbs out of a root' do
    expect(reveal(File.join(@tracker, '..', '..', 'secret.md')).status).to eq(400)
  end

  it "refuses a sibling directory sharing a root's name prefix" do
    expect(reveal(File.join("#{@tracker}-evil", 'secret.md')).status).to eq(400)
  end

  it 'refuses an empty path' do
    expect(reveal('').status).to eq(400)
  end

  it 'does not treat an unset root as a wildcard' do
    config = BaconTracker::Configuration.new
    config.namespace    = 'TST'
    config.tracker_root = @tracker # docs_root and decisions_root nil
    BaconTracker::Server.boot(config)

    expect(reveal(File.join(@docs, 'guide.md')).status).to eq(400)
    expect(reveal(File.join(@tracker, 'backlog.md')).status).to eq(200)
  end
end
