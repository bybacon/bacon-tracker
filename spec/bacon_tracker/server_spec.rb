require 'spec_helper'
require 'rack/test'
require 'bacon_tracker/server'
require 'bacon_tracker/dashboard'

RSpec.describe BaconTracker::Server do
  include Rack::Test::Methods

  def app
    BaconTracker::Server
  end

  before { header 'Host', 'localhost' }

  # Single-project mode helpers
  def boot_single(core)
    BaconTracker::Server.boot(core.config)
  end

  def boot_dashboard_mode(dashboard)
    BaconTracker::Server.boot_dashboard(dashboard)
  end

  # Build a minimal dashboard.md from a hash of {project_name => root_path}
  def write_dashboard(path, projects)
    File.write(path, projects.map { |name, root|
      slug = name.downcase.gsub(/[^a-z0-9]+/, '-')
      "## #{name}\npath: #{root}\nnamespace: TST\n"
    }.join("\n"))
  end

  context 'column ordering with a digit-containing namespace (BT-104)' do
    it 'orders columns by the trailing story number, not the namespace digit' do
      with_fixture_repo(namespace: 'B2B') do |core, _root|
        boot_single(core)
        silence_output do
          core.create('bug', 'First')       # B2B-001 (bugs)
          core.create('feature', 'Second')  # B2B-002 (features)
        end
        # icebox mixes types; all_stories yields features before bugs, so the
        # unsorted order is [B2B-002, B2B-001] - a correct numeric sort flips it,
        # while the old first-digit-run key (always "2" here) leaves it unsorted.
        get '/api/stories'
        ids = JSON.parse(last_response.body)['icebox'].map { |s| s['id'] }
        expect(ids).to eq(['B2B-001', 'B2B-002'])
      end
    end
  end

  context 'reveal path scoping in dashboard mode (BT-085)' do
    it "refuses to reveal a file under another project's root" do
      Dir.mktmpdir do |a_root|
        Dir.mktmpdir do |b_root|
          Dir.mktmpdir do |tmp|
            dash = File.join(tmp, 'dashboard.md')
            File.write(dash, "## Alpha\npath: #{a_root}\nnamespace: ALP\n\n" \
                             "## Beta\npath: #{b_root}\nnamespace: BET\n")
            boot_dashboard_mode(BaconTracker::Dashboard.new(dash))
            b_file = File.join(b_root, 'secret.md')
            File.write(b_file, 'x')
            # project 'alpha' endpoint tries to reveal a file under project 'beta'
            post '/projects/alpha/api/reveal', { path: b_file }.to_json,
                 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['error']).to match(/outside/)
          end
        end
      end
    end
  end

  # ── Single-project mode ────────────────────────────────────────────────────

  context 'in single-project mode' do
    around do |example|
      with_fixture_repo do |core, root|
        boot_single(core)
        @core = core
        @root = root
        example.run
      end
    end

    describe 'GET /api/stories' do
      it 'returns empty stages when no stories exist' do
        get '/api/stories'
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['icebox']).to eq([])
        expect(body['backlog']).to eq([])
        expect(body['started']).to eq([])
        expect(body['done']).to eq([])
      end

      it 'returns backlog stories in backlog.md order (BT-094)' do
        silence_output do
          @core.create('bug', 'A')
          @core.create('bug', 'B')
          @core.create('bug', 'C')
          %w[TST-001 TST-002 TST-003].each { |id| @core.commit(id) }
          @core.backlog_reorder(%w[TST-003 TST-001 TST-002])
        end
        get '/api/stories'
        ids = JSON.parse(last_response.body)['backlog'].map { |s| s['id'] }
        expect(ids).to eq(%w[TST-003 TST-001 TST-002])
      end

      it 'returns stories in the correct stage' do
        silence_output do
          @core.create('feature', 'Alpha')
          @core.create('bug', 'Beta')
          @core.commit('TST-001')
        end
        get '/api/stories'
        body = JSON.parse(last_response.body)
        expect(body['backlog'].map { |s| s['id'] }).to include('TST-001')
        expect(body['icebox'].map { |s| s['id'] }).to include('TST-002')
      end

      it 'exposes path but not dir fields' do
        silence_output { @core.create('chore', 'Clean up') }
        get '/api/stories'
        body = JSON.parse(last_response.body)
        story = body['icebox'].first
        expect(story.keys).to include('path')
        expect(story.keys).not_to include('dir')
      end

      it 'adds derived reverse relations (blocks/linked_from) across the board (BT-119)' do
        silence_output do
          @core.create('bug', 'Alpha') # TST-001
          @core.create('bug', 'Beta')  # TST-002
        end
        @core.update_story('TST-001', blocked_by: %w[TST-002], linked_to: %w[TST-002])
        get '/api/stories'
        by_id = JSON.parse(last_response.body)['icebox'].to_h { |s| [s['id'], s] }
        # The far story shows the computed reverse ends it never stored itself.
        expect(by_id['TST-002']['blocks']).to eq(%w[TST-001])
        expect(by_id['TST-002']['linked_from']).to eq(%w[TST-001])
        # The storing story shows its forward relations and empty reverses.
        expect(by_id['TST-001']['blocked_by']).to eq(%w[TST-002])
        expect(by_id['TST-001']['linked_to']).to eq(%w[TST-002])
        expect(by_id['TST-001']['blocks']).to eq([])
        expect(by_id['TST-001']['linked_from']).to eq([])
      end
    end

    describe 'PUT /api/stories/:id/stage' do
      it 'moves a story to the requested stage' do
        silence_output { @core.create('feature', 'Move Me') }
        put '/api/stories/TST-001/stage', { stage: '2_backlog' }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        expect(Dir.glob("#{@root}/features/2_backlog/TST-001-*")).not_to be_empty
      end

      it 'returns 400 for an invalid stage' do
        silence_output { @core.create('bug', 'Broken') }
        put '/api/stories/TST-001/stage', { stage: '99_limbo' }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)['error']).to match(/Invalid stage/)
      end

      it 'returns 400 for an unknown story ID' do
        put '/api/stories/TST-999/stage', { stage: '2_backlog' }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
      end
    end

    describe 'subtasks' do
      def story_with_subtasks
        @core.create_story('chore', 'Checklist')
        @core.update_story('TST-001', body: "- [ ] one\n- [x] two\n- [ ] three\n- [ ] four\n")
      end

      it 'includes subtask counts in GET /api/stories' do
        story_with_subtasks
        get '/api/stories'
        story = JSON.parse(last_response.body)['icebox'].first
        expect(story['subtasks']).to eq({ 'done' => 1, 'total' => 4 })
      end

      it 'includes subtask_lines body-line addresses (BT-065)' do
        story_with_subtasks
        get '/api/stories'
        story = JSON.parse(last_response.body)['icebox'].first
        expect(story['subtask_lines']).to eq([0, 1, 2, 3])
      end

      it 'omits subtask counts for stories without checkboxes' do
        @core.create_story('chore', 'Plain')
        @core.update_story('TST-001', body: "No checklist here.\n")
        get '/api/stories'
        story = JSON.parse(last_response.body)['icebox'].first
        expect(story['subtasks']).to be_nil
      end

      it 'PUT /api/stories/:id/subtasks toggles a subtask and returns new counts' do
        story_with_subtasks
        put '/api/stories/TST-001/subtasks', { index: 0, done: true }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['subtasks']).to eq({ 'done' => 2, 'total' => 4 })
        content = Dir.glob("#{@root}/chores/1_icebox/TST-001-*.md").then { |f| File.read(f.first) }
        expect(content).to include('- [x] one')
        expect(content).to include('status: icebox')
      end

      it 'returns 400 for an out-of-range index' do
        story_with_subtasks
        put '/api/stories/TST-001/subtasks', { index: 99, done: true }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)['error']).to match(/no subtask at index/)
      end

      it 'returns 400 for an unknown story' do
        put '/api/stories/TST-999/subtasks', { index: 0, done: true }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
      end
    end

    describe 'BT-063 hardening' do
      it 'returns 400 for a valid-JSON non-object body' do
        silence_output { @core.create('bug', 'Target') }
        [['/api/stories/TST-001/stage', '[]'], ['/api/stories/TST-001/subtasks', '3'],
         ['/api/stories/TST-001', '[]']].each do |path, body|
          put path, body, 'CONTENT_TYPE' => 'application/json'
          expect(last_response.status).to eq(400), "#{path} with #{body} → #{last_response.status}"
        end
        post '/api/stories', '[]', 'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
      end

      it '404s /projects/:slug API routes in single-project mode' do
        get '/projects/anything/api/stories'
        expect(last_response.status).to eq(404)
        post '/projects/anything/api/stories', { type: 'bug', title: 'X' }.to_json,
             'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(404)
      end

      it 'orders columns numerically past three-digit IDs' do
        File.write("#{@root}/features/1_icebox/TST-999-old.feature",
                   "# id: TST-999\n# type: feature\n# status: icebox\n\nFeature: Old\n")
        File.write("#{@root}/features/1_icebox/TST-1000-new.feature",
                   "# id: TST-1000\n# type: feature\n# status: icebox\n\nFeature: New\n")
        get '/api/stories'
        ids = JSON.parse(last_response.body)['icebox'].map { |s| s['id'] }
        expect(ids).to eq(%w[TST-999 TST-1000])
      end

      it 'includes a slug key in single-mode /api/stats' do
        get '/api/stats'
        expect(JSON.parse(last_response.body).first).to have_key('slug')
      end

      it 'renders identically on repeated requests (the BT-112 corruption class)' do
        # _theme_boot is a tag-free partial - the shape erubi's in-place
        # escaping used to corrupt a little more on every recompile when
        # templates lived inline in __END__. They are files now (BT-137), so
        # the registry the old spec inspected is empty; the behaviour that
        # matters is that the Nth render still carries the intact script.
        expect(BaconTracker::Server.templates).to be_empty

        first = get('/').body
        expect(first).to include("localStorage.getItem('bt-theme')")
        3.times { get '/' }
        expect(get('/').body).to eq(first)
      end
    end

    describe 'static client assets (BT-112)' do
      it 'serves /app.js and /theme.js as javascript' do
        get '/app.js'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('javascript')
        expect(last_response.body).to include('async function load()')

        get '/theme.js'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('javascript')
        expect(last_response.body).to include('function toggleTheme()')

        get '/logic.js'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('javascript')
        expect(last_response.body).to include('function storyNumber')
      end

      it 'references the extracted assets from the board HTML instead of inlining the client' do
        get '/'
        expect(last_response.body).to include('<script src="/logic.js"></script>')
        expect(last_response.body).to include('<script src="/app.js"></script>')
        expect(last_response.body).to include('window.BT_API_BASE')
        expect(last_response.body).not_to include('async function load()') # client no longer inline
      end
    end

    describe 'PUT /api/stories/backlog/order' do
      it 'reorders the backlog' do
        silence_output do
          @core.create('feature', 'First')
          @core.create('feature', 'Second')
          @core.commit('TST-001')
          @core.commit('TST-002')
        end
        put '/api/stories/backlog/order', { ids: %w[TST-002 TST-001] }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        expect(@core.backlog_ids).to eq(%w[TST-002 TST-001])
      end
    end

    describe 'POST /api/stories' do
      it 'creates a story and returns 201 with the story JSON' do
        post '/api/stories', { type: 'feature', title: 'New API Feature' }.to_json,
             'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(201)
        body = JSON.parse(last_response.body)
        expect(body['id']).to eq('TST-001')
        expect(body['type']).to eq('feature')
        expect(body['stage']).to eq('1_icebox')
        expect(Dir.glob("#{@root}/features/1_icebox/TST-001-*.feature")).not_to be_empty
      end

      it 'creates in the requested stage' do
        post '/api/stories', { type: 'bug', title: 'Backlog Bug', stage: '2_backlog' }.to_json,
             'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(201)
        expect(Dir.glob("#{@root}/bugs/2_backlog/TST-001-*.md")).not_to be_empty
      end

      it 'returns the full Story including path, matching GET/PUT (BT-089)' do
        post '/api/stories', { type: 'bug', title: 'With Path' }.to_json,
             'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(201)
        body = JSON.parse(last_response.body)
        expect(body['path']).to be_a(String)
        expect(body['path']).to include('TST-001')
      end

      it 'returns 400 for an unknown type' do
        post '/api/stories', { type: 'epic', title: 'Nope' }.to_json,
             'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)['error']).to match(/Unknown kind/)
      end
    end

    describe 'DELETE /api/stories/:id' do
      it 'deletes the story file and returns 200' do
        silence_output { @core.create('bug', 'Delete Me') }
        path = Dir.glob("#{@root}/bugs/1_icebox/TST-001-*.md").first
        delete '/api/stories/TST-001'
        expect(last_response.status).to eq(200)
        expect(File.exist?(path)).to be false
      end

      it 'returns 400 for an unknown story ID' do
        delete '/api/stories/TST-999'
        expect(last_response.status).to eq(400)
      end
    end

    describe 'PUT /api/stories/:id' do
      it 'updates the story title' do
        silence_output { @core.create('feature', 'Old Name') }
        put '/api/stories/TST-001', { title: 'New Name' }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        expect(Dir.glob("#{@root}/features/1_icebox/TST-001-new-name.feature")).not_to be_empty
      end

      it 'updates the story body' do
        silence_output { @core.create('bug', 'Crash') }
        put '/api/stories/TST-001', { body: 'Repro steps here.' }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        path = Dir.glob("#{@root}/bugs/1_icebox/TST-001-*.md").first
        expect(File.read(path)).to include('Repro steps here.')
      end

      it 'updates all five fields in a single request' do
        silence_output { @core.create('bug', 'Old Bug') }
        put '/api/stories/TST-001',
            { title: 'New Bug', body: 'Repro: open app.', size: 'M',
              blocked_by: ['TST-002'], assignee: 'AB' }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        path = Dir.glob("#{@root}/bugs/1_icebox/TST-001-new-bug.md").first
        expect(path).not_to be_nil
        content = File.read(path)
        expect(content).to include('Repro: open app.')
        expect(content).to include('size: M')
        expect(content).to include('assignee: AB')
        expect(content).to include('blocked_by: TST-002')
      end

      it 'updates linked_to (BT-119)' do
        silence_output { @core.create('bug', 'Linkable') }
        put '/api/stories/TST-001', { linked_to: ['TST-002'] }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        path = Dir.glob("#{@root}/bugs/1_icebox/TST-001-*.md").first
        expect(File.read(path)).to include('linked_to: TST-002')
      end

      it 'returns 400 for an unknown story ID' do
        put '/api/stories/TST-999', { title: 'x' }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
      end

      it 'returns the updated story object (BT-065)' do
        @core.create_story('chore', 'Before')
        put '/api/stories/TST-001', { title: 'After', body: "- [ ] step\n" }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        story = JSON.parse(last_response.body)
        expect(story['title']).to eq('after') # titles are filename-humanized, as in GET
        expect(story['subtasks']).to eq({ 'done' => 0, 'total' => 1 })
        expect(story['subtask_lines']).to eq([0])
      end

      it 'returns 400 (not 500) when the .md file has malformed frontmatter' do
        silence_output { @core.create('bug', 'Corrupt Me') }
        path = Dir.glob("#{@root}/bugs/1_icebox/TST-001-*.md").first
        File.write(path, "---\nid: TST-001\ntype: bug\nstatus: icebox")
        put '/api/stories/TST-001', { size: 'M' }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)).to have_key('error')
      end
    end

    describe 'error handler' do
      it 'returns 500 with generic JSON body and no backtrace or class names' do
        prior_raise      = BaconTracker::Server.raise_errors?
        prior_show_excep = BaconTracker::Server.show_exceptions?
        allow_any_instance_of(BaconTracker::Core).to receive(:all_stories).and_raise(RuntimeError, 'boom')
        BaconTracker::Server.set :raise_errors, false
        BaconTracker::Server.set :show_exceptions, false
        silence_errors { get '/api/stories' }
        expect(last_response.status).to eq(500)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Internal Server Error')
        expect(last_response.body).not_to match(%r{/\w+/\w+/})
        expect(last_response.body).not_to include('RuntimeError')
      ensure
        BaconTracker::Server.set :raise_errors, prior_raise
        BaconTracker::Server.set :show_exceptions, prior_show_excep
      end
    end

    describe 'POST /api/reveal' do
      it 'returns ok and launches the reveal for a path inside the docs root' do
        # spec_helper stubs Launcher.run, so nothing is actually spawned (BT-096).
        path = File.join(@root, 'backlog.md')
        post '/api/reveal', { path: path }.to_json, 'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)['ok']).to be true
        expect(BaconTracker::Launcher).to have_received(:run).with(['open', '-R', path])
      end

      it 'returns 501 with the reason when the platform has no launcher (BT-179)' do
        allow(BaconTracker::Launcher).to receive(:host_os).and_return('linux-gnu')
        allow(BaconTracker::Launcher).to receive(:which).and_return(false)
        allow(BaconTracker::Launcher).to receive(:run).and_call_original
        post '/api/reveal', { path: File.join(@root, 'backlog.md') }.to_json,
             'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(501)
        expect(JSON.parse(last_response.body)['error']).to include('no launcher')
      end

      it 'returns 400 when path is outside all tracked directories' do
        post '/api/reveal', { path: '/etc/passwd' }.to_json, 'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)['error']).to include('outside')
      end

      it 'returns 400 for a sibling path that only shares the root as a prefix (BT-096)' do
        # e.g. root=/docs must not authorize /docs-evil/secret - the guard uses
        # root + File::SEPARATOR exactly for this.
        post '/api/reveal', { path: "#{@root}-evil/secret.md" }.to_json,
             'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)['error']).to include('outside')
      end

      it 'returns 400 when path key is missing' do
        post '/api/reveal', {}.to_json, 'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)['error']).to include('path required')
      end
    end

    describe 'hardening' do
      it 'sets anti-framing and nosniff headers on every response (BT-116)' do
        get '/api/stories'
        expect(last_response.headers['X-Frame-Options']).to eq('DENY')
        expect(last_response.headers['X-Content-Type-Options']).to eq('nosniff')
        expect(last_response.headers['Content-Security-Policy']).to match(/frame-ancestors 'none'/)
      end

      it 'rejects an oversized request body with 413 (BT-116)' do
        big = { type: 'bug', title: 'x' * 2_000_000 }.to_json
        post '/api/stories', big, 'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(413)
      end

      it 'rejects a state-changing request from a cross-origin Origin (BT-085)' do
        post '/api/stories', { type: 'bug', title: 'X' }.to_json,
             'CONTENT_TYPE' => 'application/json', 'HTTP_ORIGIN' => 'http://evil.example'
        expect(last_response.status).to eq(403)
        expect(Dir.glob("#{@root}/bugs/**/TST-*.md")).to be_empty # not created
      end

      it 'allows a state-changing request from a localhost Origin (BT-085)' do
        post '/api/stories', { type: 'bug', title: 'X' }.to_json,
             'CONTENT_TYPE' => 'application/json', 'HTTP_ORIGIN' => 'http://localhost:4567'
        expect(last_response.status).to eq(201)
      end
    end

    describe 'GET /api/stats' do
      it 'returns a single-element array with counts' do
        silence_output do
          @core.create('feature', 'Alpha')
          @core.create('bug', 'Beta')
          @core.commit('TST-001')
        end
        get '/api/stats'
        expect(last_response.status).to eq(200)
        stats = JSON.parse(last_response.body)
        expect(stats).to be_an(Array)
        expect(stats.first['backlog']).to eq(1)
        expect(stats.first['icebox']).to eq(1)
      end
    end

    describe 'XSS payload in story content' do
      let(:xss_body) { '<img src=x onerror=alert(1)><script>alert(1)</script>' }

      it 'stores body XSS payload verbatim and returns it as raw JSON - client-side esc() handles rendering' do
        silence_output { @core.create('bug', 'xss test') }
        put '/api/stories/TST-001', { body: xss_body }.to_json,
            'CONTENT_TYPE' => 'application/json'
        get '/api/stories'
        story = JSON.parse(last_response.body)['icebox'].first
        expect(story['body']).to include(xss_body)
      end

      it 'does not embed story body content in the initial page HTML (stories load via JS fetch)' do
        silence_output { @core.create('bug', 'xss test') }
        put '/api/stories/TST-001', { body: xss_body }.to_json,
            'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200) # payload was actually stored - assertions below aren't vacuous
        get '/'
        expect(last_response.body).not_to include('<script>alert(1)</script>')
        expect(last_response.body).not_to include(xss_body)
      end
    end

    describe 'GET / (index template)' do
      it 'renders 200 with the four stage columns' do
        get '/'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('text/html')
        %w[1_icebox 2_backlog 3_started 4_done].each do |stage|
          expect(last_response.body).to include(%(data-stage="#{stage}"))
        end
      end

      it "carries the detail view's stage pill styling for every stage (BT-178)" do
        get '/'
        %w[1_icebox 2_backlog 3_started].each do |stage|
          expect(last_response.body).to include(%(.detail-stage[data-stage="#{stage}"]))
        end
      end

      it 'displays the project namespace' do
        get '/'
        expect(last_response.body).to include('>TST<')
      end

      it 'renders the mobile tab bar and theme toggle' do
        get '/'
        expect(last_response.body).to include('mobile-tabs')
        expect(last_response.body).to include('theme-toggle')
      end

      it 'omits the back link in single-project mode' do
        get '/'
        expect(last_response.body).not_to include('← dashboard')
      end

      it 'serves byte-identical, uncorrupted JS on repeated renders' do
        get '/'
        first = last_response.body
        get '/'
        expect(last_response.body).to eq(first)
        expect(last_response.body).to include("localStorage.getItem('bt-theme')")
        expect(last_response.body).not_to include("\\'bt-theme\\'")
      end

      it 'escapes HTML special characters in the namespace' do
        with_fixture_repo(namespace: 'X<>"') do |core, _|
          BaconTracker::Server.boot(core.config)
          get '/'
          expect(last_response.body).not_to include('X<>"')
          expect(last_response.body).to include('X&lt;&gt;&quot;')
        end
      end
    end
  end

  # ── Dashboard mode ─────────────────────────────────────────────────────────

  context 'in dashboard mode' do
    around do |example|
      with_fixture_repo do |core, root|
        Dir.mktmpdir do |tmpdir|
          dash_path = File.join(tmpdir, 'dashboard.md')
          write_dashboard(dash_path, { 'My Project' => root })
          dashboard = BaconTracker::Dashboard.new(dash_path)
          boot_dashboard_mode(dashboard)
          @core = core
          @root = root
          @dash_path = dash_path
          example.run
        end
      end
    end

    describe 'GET /api/stats' do
      it 'returns project stats array' do
        get '/api/stats'
        expect(last_response.status).to eq(200)
        stats = JSON.parse(last_response.body)
        expect(stats.first['name']).to eq('My Project')
      end
    end

    describe 'editing dashboard.md while the server runs' do
      it 'picks up a newly added project without a restart (via a live HTTP request)' do
        get '/api/stats'
        expect(JSON.parse(last_response.body).map { |p| p['name'] }).to eq(['My Project'])

        # Append a project to the SAME dashboard.md the running server booted with.
        File.write(@dash_path, "#{File.read(@dash_path)}\n## Second\npath: #{@root}\nnamespace: SEC\n")
        FileUtils.touch(@dash_path, mtime: Time.now + 5)

        get '/api/stats'
        expect(JSON.parse(last_response.body).map { |p| p['name'] }).to include('My Project', 'Second')
      end
    end

    describe 'GET /projects/:slug/api/stories' do
      it 'returns stories for the project' do
        get '/projects/my-project/api/stories'
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body).to have_key('icebox')
      end

      it 'returns 404 for an unknown slug' do
        get '/projects/does-not-exist/api/stories'
        expect(last_response.status).to eq(404)
      end
    end

    describe 'GET / (dashboard template)' do
      it 'renders 200 with project cards' do
        get '/'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('text/html')
        expect(last_response.body).to include('project-card')
        expect(last_response.body).to include('My Project')
      end

      it 'renders the theme toggle' do
        get '/'
        expect(last_response.body).to include('theme-toggle')
      end

      it 'marks a project with started stories as h-active' do
        silence_output do
          @core.create('feature', 'WIP')
          @core.commit('TST-001')
          @core.set_stage('TST-001', '3_started')
        end
        get '/'
        expect(last_response.body).to include('h-active')
      end

      it 'marks a project with backlog but no started as h-idle' do
        silence_output do
          @core.create('feature', 'Ready')
          @core.commit('TST-001')
        end
        get '/'
        expect(last_response.body).to include('h-idle')
      end

      it 'omits counts that are zero' do
        get '/'
        # fixture has no stories - no count spans rendered
        expect(last_response.body).not_to match(/\d+ (?:done|started|backlog|icebox)/)
      end

      it 'renders non-zero counts' do
        silence_output do
          @core.create('feature', 'A')
          @core.create('bug', 'B')
          @core.commit('TST-001')
        end
        get '/'
        expect(last_response.body).to match(/\d+ (?:done|started|backlog|icebox)/)
      end

      it 'shows the empty state when no projects are configured' do
        Dir.mktmpdir do |tmpdir|
          dash_path = File.join(tmpdir, 'empty.md')
          File.write(dash_path, '')
          boot_dashboard_mode(BaconTracker::Dashboard.new(dash_path))
          get '/'
          expect(last_response.status).to eq(200)
          expect(last_response.body).to include('No projects found')
        end
      end

      it 'escapes HTML in project names' do
        with_fixture_repo do |_, root|
          Dir.mktmpdir do |tmpdir|
            dash_path = File.join(tmpdir, 'dashboard.md')
            File.write(dash_path, "## <script>alert(1)</script>\npath: #{root}\nnamespace: XSS\n")
            boot_dashboard_mode(BaconTracker::Dashboard.new(dash_path))
            get '/'
            expect(last_response.body).not_to include('<script>alert(1)</script>')
            expect(last_response.body).to include('&lt;script&gt;')
          end
        end
      end
    end

    describe 'GET /projects/:slug (per-project board)' do
      it 'renders 200 with back link and namespace' do
        get '/projects/my-project'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('text/html')
        expect(last_response.body).to include('← dashboard')
        expect(last_response.body).to include('TST')
      end

      it 'returns 404 for an unknown slug' do
        get '/projects/does-not-exist'
        expect(last_response.status).to eq(404)
      end
    end

    describe 'PUT /projects/:slug/api/stories/:id/stage' do
      it 'moves a story via the dashboard route' do
        with_fixture_repo do |core, root|
          silence_output { core.create('feature', 'Dashboard story') }

          Dir.mktmpdir do |tmpdir|
            dash_path = File.join(tmpdir, 'dashboard.md')
            write_dashboard(dash_path, { 'My Project' => root })
            boot_dashboard_mode(BaconTracker::Dashboard.new(dash_path))

            put '/projects/my-project/api/stories/TST-001/stage',
                { stage: '2_backlog' }.to_json,
                'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq(200)
            expect(Dir.glob("#{root}/features/2_backlog/TST-001-*")).not_to be_empty
          end
        end
      end
    end

    describe 'PUT /projects/:slug/api/stories/:id/subtasks' do
      it 'toggles a subtask via the dashboard route' do
        with_fixture_repo do |core, root|
          core.create_story('chore', 'Checklist')
          core.update_story('TST-001', body: "- [ ] one\n")

          Dir.mktmpdir do |tmpdir|
            dash_path = File.join(tmpdir, 'dashboard.md')
            write_dashboard(dash_path, { 'My Project' => root })
            boot_dashboard_mode(BaconTracker::Dashboard.new(dash_path))

            put '/projects/my-project/api/stories/TST-001/subtasks',
                { index: 0, done: true }.to_json,
                'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)['subtasks']).to eq({ 'done' => 1, 'total' => 1 })
          end
        end
      end
    end
  end
end

RSpec.describe BaconTracker::Launcher do
  around do |example|
    saved = ENV['BACON_EDITOR']
    example.run
  ensure
    ENV['BACON_EDITOR'] = saved
  end

  it 'splits BACON_EDITOR so an editor with arguments works (BT-179)' do
    ENV['BACON_EDITOR'] = 'code -w'
    expect(described_class.open_argv('/x/a b.md')).to eq(['code', '-w', '/x/a b.md'])
  end

  it 'reveals with open -R on macOS and the containing folder via xdg-open on Linux' do
    ENV.delete('BACON_EDITOR')
    expect(described_class.reveal_argv('/x/a.md')).to eq(['open', '-R', '/x/a.md'])

    allow(described_class).to receive(:host_os).and_return('linux-gnu')
    allow(described_class).to receive(:which).with('xdg-open').and_return(true)
    expect(described_class.reveal_argv('/x/a.md')).to eq(['xdg-open', '/x'])
    expect(described_class.open_argv('/x/a.md')).to eq(['xdg-open', '/x/a.md'])
  end

  it 'has no argv when Linux lacks xdg-open, and run then raises Unavailable' do
    allow(described_class).to receive(:host_os).and_return('linux-gnu')
    allow(described_class).to receive(:which).and_return(false)
    allow(described_class).to receive(:run).and_call_original
    expect(described_class.reveal_argv('/x/a.md')).to be_nil
    expect { described_class.run(nil) }.to raise_error(described_class::Unavailable)
  end
end
