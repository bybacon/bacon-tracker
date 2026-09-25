require 'spec_helper'
require 'rack/test'
require 'bacon_tracker/server'

def docs_core
  with_fixture_repo(decisions: true) do |core, _root|
    docs = File.dirname(core.config.decisions_root)
    core.config.docs_root = docs
    FileUtils.mkdir_p(File.join(docs, 'guides'))
    FileUtils.mkdir_p(File.join(docs, 'guides', 'deep'))
    FileUtils.mkdir_p(File.join(docs, 'images'))
    File.write(File.join(docs, 'guides', 'setup.md'), "# Setup\nHello.\n")
    File.write(File.join(docs, 'guides', 'deep', 'nested.txt'), "deep\n")
    File.write(File.join(docs, 'images', 'logo.png'), '')
    File.write(File.join(docs, 'Home.md'), "# Home\n")
    File.write(File.join(docs, '_draft.md'), "hidden\n")
    File.write(File.join(docs, '.secret.md'), "dot\n")
    write_decision(core, status: 'accepted', id: 1)
    yield core, docs
  end
end

RSpec.describe 'docs browser (BT-139)' do
  describe 'Core#docs_tree' do
    it 'lists folders and loose pages, hiding invisibles and non-pages' do
      docs_core do |core, _|
        top = core.docs_tree
        names = top.map { |n| n[:name] }
        expect(names).to include('guides', 'decisions', 'Home.md')
        expect(names).not_to include('_draft.md', '.secret.md', 'images') # images: nothing renderable
        guides = top.find { |n| n[:name] == 'guides' }
        expect(guides[:type]).to eq('dir')
        expect(guides[:children].map { |n| n[:name] }).to contain_exactly('deep', 'setup.md')
      end
    end

    it 'marks the decisions directory as board-bound (BT-176)' do
      docs_core do |core, _|
        node = core.docs_tree.find { |n| n[:name] == 'decisions' }
        expect(node[:decisions]).to be(true)
        expect(core.docs_tree.find { |n| n[:name] == 'guides' }[:decisions]).to be_nil
      end
    end

    it 'hides the machinery inside a tracked subtree but lists its records' do
      docs_core do |core, _|
        decisions = core.docs_tree.find { |n| n[:name] == 'decisions' }
        all = []
        walk = ->(nodes) { nodes.each { |n| all << n[:name]; walk.(n[:children] || []) } }
        walk.(decisions[:children])
        expect(all).to include('TST-ADR-0001-a-decision.md')
        expect(all).not_to include('proposed.md', '_template.md', '.next-id')
      end
    end

    it 'hides a tracker tree living inside the docs tree' do
      docs_core do |core, docs|
        FileUtils.mkdir_p(File.join(docs, 'tracker'))
        File.write(File.join(docs, 'tracker', 'backlog.md'), '')
        core.config.tracker_root = File.join(docs, 'tracker')
        expect(core.docs_tree.map { |n| n[:name] }).not_to include('tracker')
      end
    end
  end

  describe 'Core#docs_page' do
    it 'reads a page by its docs-relative path' do
      docs_core do |core, _|
        expect(core.docs_page('guides/setup.md')).to include('Hello.')
      end
    end

    it 'refuses traversal, absolute paths, non-pages and hidden files - without content' do
      docs_core do |core, docs|
        %w[../secret.md /etc/passwd guides/../../x.md images/logo.png _draft.md .secret.md].each do |bad|
          expect { core.docs_page(bad) }.to raise_error(ArgumentError), "expected refusal for #{bad}"
        end
      end
    end
  end

  describe 'rendering (BT-140)' do
    it 'renders markdown to themed HTML with task-list checkboxes' do
      docs_core do |core, docs|
        File.write(File.join(docs, 'guides', 'list.md'),
                   "# Title\n\n- [ ] open\n- [x] closed\n\n| a | b |\n|---|---|\n| 1 | 2 |\n")
        html = core.render_page('guides/list.md')[:html]
        expect(html).to include('<h1')
        expect(html.scan(/type="checkbox"/).size).to eq(2)
        expect(html).to include('<table')
      end
    end

    it 'keeps txt plain - escaped, not parsed' do
      docs_core do |core, docs|
        File.write(File.join(docs, 'notes.txt'), "# not a heading <b>\n")
        html = core.render_page('notes.txt')[:html]
        expect(html).not_to include('<h1')
        expect(html).to include('&lt;b&gt;')
      end
    end

    it 'separates frontmatter into fields instead of rendering raw YAML (BT-141)' do
      docs_core do |core, _|
        page = core.render_page('decisions/accepted/TST-ADR-0001-a-decision.md')
        expect(page[:frontmatter]).to include('status' => 'accepted', 'date' => '2026-09-14')
        expect(page[:html]).not_to include('status:')
        expect(page[:title]).to eq('A decision')
      end
    end

    it 'titles a page from its heading, falling back to the filename' do
      docs_core do |core, docs|
        expect(core.render_page('guides/setup.md')[:title]).to eq('Setup')
        File.write(File.join(docs, 'guides', 'untitled.md'), "no heading here\n")
        expect(core.render_page('guides/untitled.md')[:title]).to eq('untitled.md')
      end
    end

    it 'serves html from the page endpoint' do
      docs_core do |core, _|
        BaconTracker::Server.boot(core.config)
        body = JSON.parse(get('/api/docs/page', { path: 'guides/setup.md' }).body)
        expect(body['html']).to include('<h1')
        expect(body['content']).to include('# Setup')
      end
    end

    include Rack::Test::Methods
    def app = BaconTracker::Server
    before { header 'Host', 'localhost' }
  end

  describe 'the decisions board (BT-144)' do
    include Rack::Test::Methods
    def app = BaconTracker::Server
    before { header 'Host', 'localhost' }

    it 'lists records with title, status, date and relations' do
      docs_core do |core, _|
        write_decision(core, status: 'superseded', id: 2, slug: 'old',
                       frontmatter: "---\nstatus: superseded\ndate: 2026-02-01\nsuperseded_by: [TST-ADR-0001]\n---\n")
        BaconTracker::Server.boot(core.config)
        list = JSON.parse(get('/api/decisions').body)
        expect(list.size).to eq(2)
        old_rec = list.find { |r| r['id'] == 'TST-ADR-0002' }
        expect(old_rec).to include('status' => 'superseded', 'title' => 'Old',
                                   'superseded_by' => ['TST-ADR-0001'])
        expect(old_rec['docs_path']).to eq('decisions/superseded/TST-ADR-0002-old.md')
      end
    end

    it 'serves the board page with one column per status, and 404s with no decisions' do
      docs_core do |core, _|
        BaconTracker::Server.boot(core.config)
        body = get('/docs/decisions').body
        expect(body).to include('id="decision-board"').and include('decisions.js')
        # dark theme rides the shared partials - a page missing these renders
        # white cards on a dark board (BT-177)
        expect(body).to include('[data-theme="dark"] .card')
        expect(body).to include('[data-theme="dark"] header')
        # the detail head states the status directory the record lives in,
        # coloured like its column (BT-178)
        expect(body).to include('id="doc-detail-status"')
        expect(body).to include('.detail-stage[data-status="accepted"]')

        core.config.decisions_root = nil
        BaconTracker::Server.boot(core.config)
        expect(get('/docs/decisions').status).to eq(404)
      end
    end
  end

  describe 'POST /api/decisions (BT-146)' do
    include Rack::Test::Methods
    def app = BaconTracker::Server
    before { header 'Host', 'localhost'; header 'Content-Type', 'application/json' }

    it 'creates a proposed record and refuses a blank title' do
      docs_core do |core, _|
        BaconTracker::Server.boot(core.config)
        res = post('/api/decisions', { title: 'Choose a queue' }.to_json)
        expect(res.status).to eq(200)
        expect(JSON.parse(res.body)['path']).to match(/TST-ADR-\d{4}-choose-a-queue\.md/)
        expect(post('/api/decisions', { title: ' ' }.to_json).status).to eq(400)
      end
    end
  end

  describe 'file actions (BT-142, BT-143)' do
    include Rack::Test::Methods
    def app = BaconTracker::Server
    before { header 'Host', 'localhost'; header 'Content-Type', 'application/json' }

    it 'opens a page in the editor, refusing anything the tree would not list' do
      docs_core do |core, _|
        BaconTracker::Server.boot(core.config)
        expect(post('/api/docs/editor', { path: 'guides/setup.md' }.to_json).status).to eq(200)
        %w[../secret.md _draft.md images/logo.png].each do |bad|
          expect(post('/api/docs/editor', { path: bad }.to_json).status).to eq(400)
        end
      end
    end

    it 'reveals a page or a folder, refusing escapes' do
      docs_core do |core, _|
        BaconTracker::Server.boot(core.config)
        expect(post('/api/docs/reveal', { path: 'guides/setup.md' }.to_json).status).to eq(200)
        expect(post('/api/docs/reveal', { path: 'guides' }.to_json).status).to eq(200)
        expect(post('/api/docs/reveal', { path: '../..' }.to_json).status).to eq(400)
        expect(post('/api/docs/reveal', { path: '.git' }.to_json).status).to eq(400)
      end
    end
  end

  describe 'the endpoints' do
    include Rack::Test::Methods
    def app = BaconTracker::Server
    before { header 'Host', 'localhost' }

    it 'serves the browser page and its client' do
      docs_core do |core, _|
        BaconTracker::Server.boot(core.config)
        page = get('/docs')
        expect(page.body).to include('id="doc-columns"').and include('id="doc-preview"')

        js = get('/docs.js')
        expect(js.status).to eq(200)
        expect(js.content_type).to include('javascript')
        expect(js.body).to include('doc-col')
      end
    end

    it 'serves the tree, a page, and refuses an escape' do
      docs_core do |core, _|
        BaconTracker::Server.boot(core.config)
        tree = JSON.parse(get('/api/docs/tree').body)
        expect(tree.map { |n| n['name'] }).to include('guides')

        page = get('/api/docs/page', { path: 'guides/setup.md' })
        expect(page.status).to eq(200)
        expect(JSON.parse(page.body)['content']).to include('Hello.')

        bad = get('/api/docs/page', { path: '../../etc/passwd' })
        expect(bad.status).to eq(400)
        expect(bad.body).not_to include('root:')
      end
    end
  end
end

RSpec.describe 'the project front (BT-149)' do
  def front_core
    with_fixture_repo(decisions: true) do |core, root|
      proj = File.join(root, 'proj')
      FileUtils.mkdir_p(File.join(proj, 'docs'))
      core.config.project_root = proj
      core.config.docs_root    = File.join(proj, 'docs')
      yield core, proj
    end
  end

  it 'serves README, CHANGELOG and VERSION when present' do
    front_core do |core, proj|
      File.write(File.join(proj, 'README.md'), "# Hello\n")
      File.write(File.join(proj, 'CHANGELOG.md'), "# Changelog\n\n## [1.2.0]\n- x\n")
      File.write(File.join(proj, 'VERSION'), "1.2.0\n")
      front = core.project_front
      expect(front[:readme_html]).to include('<h1')
      expect(front[:changelog_html]).to include('1.2.0')
      expect(front[:version]).to eq('1.2.0')
    end
  end

  it 'finds VERSION one level deep by the fixed search order' do
    front_core do |core, proj|
      FileUtils.mkdir_p(File.join(proj, 'app'))
      File.write(File.join(proj, 'app', 'VERSION'), '3.1.4')
      expect(core.project_front[:version]).to eq('3.1.4')
    end
  end

  it 'reports ambiguity instead of guessing between two candidates' do
    front_core do |core, proj|
      FileUtils.mkdir_p(File.join(proj, 'app'))
      FileUtils.mkdir_p(File.join(proj, 'web'))
      File.write(File.join(proj, 'app', 'VERSION'), '1')
      File.write(File.join(proj, 'web', 'VERSION'), '2')
      front = core.project_front
      expect(front[:version]).to be_nil
      expect(front[:version_ambiguous]).to eq(%w[app/VERSION web/VERSION])
    end
  end

  it 'lets an explicit version path override the search entirely' do
    front_core do |core, proj|
      FileUtils.mkdir_p(File.join(proj, 'app'))
      FileUtils.mkdir_p(File.join(proj, 'build'))
      File.write(File.join(proj, 'app', 'VERSION'), 'wrong')
      File.write(File.join(proj, 'build', 'VERSION'), '5.0.0')
      core.config.version_path = 'build/VERSION'
      expect(core.project_front[:version]).to eq('5.0.0')
    end
  end

  it 'omits everything gracefully when nothing exists' do
    front_core do |core, _|
      front = core.project_front
      expect(front[:readme_html]).to be_nil
      expect(front[:changelog_html]).to be_nil
      expect(front[:version]).to be_nil
    end
  end
end

RSpec.describe 'docs search (BT-150)' do
  it 'finds pages and decisions, grouped data with the matching line' do
    docs_core do |core, docs|
      File.write(File.join(docs, 'guides', 'ops.md'), "# Ops\n\nDone is append-only here.\n")
      write_decision(core, status: 'accepted', id: 3, slug: 'append',
                     body: "We keep done append-only.\n")
      hits = core.docs_search('append-only')
      paths = hits.map { |h| h[:path] }
      expect(paths).to include('guides/ops.md')
      expect(paths.any? { |p| p.include?('TST-ADR-0003') }).to be(true)
      ops = hits.find { |h| h[:path] == 'guides/ops.md' }
      expect(ops[:line]).to include('append-only')
      expect(ops[:lineno]).to eq(3)
    end
  end

  it 'matches case-insensitively and never searches hidden files' do
    docs_core do |core, docs|
      File.write(File.join(docs, '_template.md'), "xylophone\n")
      expect(core.docs_search('XYLOPHONE')).to be_empty
      File.write(File.join(docs, 'loud.md'), "XyloPhone solo\n")
      expect(core.docs_search('xylophone').size).to eq(1)
    end
  end

  it 'returns nothing for a blank query and caps runaway result sets' do
    docs_core do |core, docs|
      expect(core.docs_search('  ')).to eq([])
      File.write(File.join(docs, 'big.md'), "match\n" * 500)
      expect(core.docs_search('match').size).to be <= 3
    end
  end

  describe 'the endpoint' do
    include Rack::Test::Methods
    def app = BaconTracker::Server
    before { header 'Host', 'localhost' }

    it 'serves grouped hits' do
      docs_core do |core, _|
        BaconTracker::Server.boot(core.config)
        hits = JSON.parse(get('/api/docs/search', { q: 'Hello' }).body)
        expect(hits.first).to include('path' => 'guides/setup.md')
      end
    end
  end
end

RSpec.describe 'recently changed (BT-151)' do
  def git!(dir, *args)
    system('git', '-C', dir, *args, out: File::NULL, err: File::NULL) or raise "git #{args.first} failed"
  end

  def with_git_docs
    docs_core do |core, docs|
      git!(docs, 'init', '-q')
      git!(docs, 'config', 'user.email', 't@t')
      git!(docs, 'config', 'user.name', 't')
      git!(docs, 'add', '-A')
      git!(docs, 'commit', '-qm', 'first')
      yield core, docs
    end
  end

  it 'lists pages newest-first from git history, not mtime' do
    with_git_docs do |core, docs|
      File.write(File.join(docs, 'guides', 'setup.md'), "# Setup\nEdited.\n")
      git!(docs, 'add', '-A'); git!(docs, 'commit', '-qm', 'edit setup')
      # touch a file without committing - mtime changes, history does not
      FileUtils.touch(File.join(docs, 'Home.md'))

      recent = core.docs_recent
      expect(recent.first[:path]).to eq('guides/setup.md')
      expect(recent.map { |r| r[:path] }).to include('Home.md') # from the first commit
      expect(recent.index { |r| r[:path] == 'Home.md' }).to be > 0
    end
  end

  it 'hides invisible files and is empty without a repository' do
    with_git_docs do |core, docs|
      expect(core.docs_recent.map { |r| r[:path] }).not_to include('_draft.md', '.secret.md')
    end
    docs_core do |core, _|
      expect(core.docs_recent).to eq([])
    end
  end
end

RSpec.describe 'backlinks (BT-152)' do
  it 'lists the pages linking to a page, and says so when none do' do
    docs_core do |core, docs|
      File.write(File.join(docs, 'guides', 'linker.md'),
                 "# Linker\nSee [setup](setup.md) and [home](../Home.md).\n")
      expect(core.docs_backlinks('guides/setup.md').map { |b| b[:path] }).to eq(['guides/linker.md'])
      expect(core.docs_backlinks('Home.md').map { |b| b[:path] }).to eq(['guides/linker.md'])
      expect(core.docs_backlinks('guides/linker.md')).to eq([])
    end
  end

  it 'lists a decision cited by another decision, by id' do
    docs_core do |core, _|
      write_decision(core, status: 'accepted', id: 5, slug: 'target')
      write_decision(core, status: 'accepted', id: 6, slug: 'citer',
                     body: "Builds on TST-ADR-0005.\n")
      hits = core.docs_backlinks('decisions/accepted/TST-ADR-0005-target.md')
      expect(hits.map { |b| b[:path] }).to eq(['decisions/accepted/TST-ADR-0006-citer.md'])
    end
  end
end

RSpec.describe 'GitHub-style tables (BT-173)' do
  it 'renders a table butted directly against its heading' do
    docs_core do |core, docs|
      File.write(File.join(docs, 'guides', 'tight.md'),
                 "### Auth concerns\n| a | b |\n|---|---|\n| 1 | 2 |\n")
      expect(core.render_page('guides/tight.md')[:html]).to include('<table')
    end
  end

  it 'leaves pipe lines inside fenced code untouched' do
    docs_core do |core, docs|
      File.write(File.join(docs, 'guides', 'fenced.md'),
                 "text\n```\nx | y\n| a | b |\n|---|---|\n```\n")
      html = core.render_page('guides/fenced.md')[:html]
      expect(html).not_to include('<table')
      expect(html).to include('| a | b |')
    end
  end
end
