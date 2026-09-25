require 'spec_helper'
require 'rack/test'
require 'bacon_tracker/server'
require 'bacon_tracker/dashboard'

RSpec.describe 'docs surface entry (BT-138)' do
  include Rack::Test::Methods
  def app = BaconTracker::Server

  before { header 'Host', 'localhost' }

  # base holds two projects: "both" (tracker + docs) and "docsonly" (docs alone).
  def build_fleet(base)
    both = File.join(base, 'both')
    FileUtils.mkdir_p(File.join(both, 'tracker'))
    File.write(File.join(both, 'tracker', 'backlog.md'), '')
    FileUtils.mkdir_p(File.join(both, 'docs', 'decisions', 'proposed'))
    File.write(File.join(both, 'docs', 'guide.md'), "# G\n")

    docsonly = File.join(base, 'docsonly')
    FileUtils.mkdir_p(File.join(docsonly, 'docs', 'decisions', 'proposed'))
    File.write(File.join(docsonly, 'docs', 'one.md'), "# One\n")
    File.write(File.join(docsonly, 'docs', 'two.md'), "# Two\n")
    File.write(File.join(docsonly, 'docs', 'decisions', 'proposed', 'DOC-ADR-0001-pick.md'),
               "---\nstatus: proposed\ndate: 2026-09-14\n---\n\n# Pick\n")

    dash = File.join(base, 'dashboard.md')
    File.write(dash, <<~MD)
      ## Both
      path: ./both
      namespace: BTH

      ## Docs Only
      path: ./docsonly
      namespace: DOC
    MD
    BaconTracker::Server.boot_dashboard(BaconTracker::Dashboard.new(dash))
  end

  it 'offers both surfaces on a two-surface card, and only the board otherwise' do
    Dir.mktmpdir do |base|
      build_fleet(base)
      body = get('/').body
      expect(body).to include('open tracker').and include('open docs')
      expect(body).to include(%(href="/projects/both/docs"))
    end
  end

  it 'offers open adrs only where decisions exist (BT-173)' do
    Dir.mktmpdir do |base|
      build_fleet(base)
      body = get('/').body
      # docs-only project has one proposed decision -> adrs action
      expect(body).to include(%(href="/projects/docs-only/docs/decisions"))
      # "both" has an empty decisions tree -> no adrs action for it
      expect(body).not_to include(%(href="/projects/both/docs/decisions">open adrs))
    end
  end

  it 'backs out to the dashboard with a single link (BT-173)' do
    Dir.mktmpdir do |base|
      build_fleet(base)
      docs = get('/projects/both/docs').body
      expect(docs).to include(%(href="/" class="back-link">← dashboard))
      expect(docs.scan(%(class="back-link")).size).to eq(1)
    end
  end

  it 'shows docs counts instead of story stats on a docs-only card' do
    Dir.mktmpdir do |base|
      build_fleet(base)
      body = get('/').body
      expect(body).to include('2 pages').and include('1 decisions').and include('1 proposed')
      # docs-only card: no progress bar, and its primary is the docs surface
      expect(body).to include(%(data-href="/projects/docs-only/docs"))
    end
  end

  it 'serves the docs surface per project, 404ing where there is none' do
    Dir.mktmpdir do |base|
      build_fleet(base)
      expect(get('/projects/both/docs').status).to eq(200)
      # the header carries no decisions link (BT-176); the sidebar's marked
      # decisions node is the way to the board
      expect(get('/projects/both/docs').body).not_to include('>decisions</a>')
      tree = JSON.parse(get('/projects/both/api/docs/tree').body)
      expect(tree.find { |n| n['name'] == 'decisions' }).to be_nil.or include('decisions' => true)

      FileUtils.rm_rf(File.join(base, 'both', 'docs'))
      expect(get('/projects/both/docs').status).to eq(404)
    end
  end

  it "wears the board's header and content styling (BT-172)" do
    with_fixture_repo(decisions: true) do |core, _|
      core.config.docs_root = File.dirname(core.config.decisions_root)
      BaconTracker::Server.boot(core.config)

      docs = get('/docs').body
      expect(docs).to include('carrot-mark').and include('theme-toggle').and include('/theme.js')
      expect(docs).to include('id="doc-preview" class="md-content"')

      board = get('/docs/decisions').body
      expect(board).to include('carrot-mark').and include('theme-toggle').and include('/theme.js')
      expect(board).to include('class="detail-body md-content"')
    end
  end

  it 'serves /docs in single-project mode when a docs root is configured' do
    with_fixture_repo(decisions: true) do |core, _|
      core.config.docs_root = File.dirname(core.config.decisions_root)
      BaconTracker::Server.boot(core.config)
      expect(get('/docs').status).to eq(200)

      core.config.docs_root = nil
      BaconTracker::Server.boot(core.config)
      expect(get('/docs').status).to eq(404)
    end
  end
end
