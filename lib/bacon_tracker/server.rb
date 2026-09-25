require 'sinatra/base'
require 'json'
require 'uri'
require 'bacon_tracker/launcher'

module BaconTracker
  class Server < Sinatra::Base
    # Cap request bodies - stories are tiny; anything larger is a mistake or an
    # attempt to exhaust memory via request.body.read (BT-116).
    MAX_BODY_BYTES = 1_000_000

    # Origins allowed to make state-changing (POST/PUT/DELETE) requests. The
    # board is same-origin on localhost; this blocks cross-site CSRF (BT-085).
    PERMITTED_ORIGIN_HOSTS = %w[localhost 127.0.0.1 ::1].freeze

    # The client is served as static assets (extracted from the inline templates
    # so it can be linted, syntax-checked, and unit-tested - BT-112). Read once
    # at load; they never change at runtime.
    ASSETS_DIR = File.expand_path('assets', __dir__).freeze
    APP_JS     = File.read(File.join(ASSETS_DIR, 'app.js')).freeze
    THEME_JS   = File.read(File.join(ASSETS_DIR, 'theme.js')).freeze
    LOGIC_JS   = File.read(File.join(ASSETS_DIR, 'logic.js')).freeze
    DOCS_JS    = File.read(File.join(ASSETS_DIR, 'docs.js')).freeze
    DECISIONS_JS = File.read(File.join(ASSETS_DIR, 'decisions.js')).freeze

    def self.boot(config)
      @mode      = :single
      @bt_core   = Core.new(config)
      @dashboard = nil
      self
    end

    def self.boot_dashboard(dashboard)
      @mode      = :dashboard
      @dashboard = dashboard
      @bt_core   = nil
      self
    end

    # Route patterns are registered for both single mode and the
    # dashboard-mode /projects/:slug prefix.
    def self.scoped(path)
      [path, "/projects/:slug#{path}"]
    end

    def self.bt_core      = @bt_core
    def self.bt_dashboard = @dashboard
    def self.dashboard_mode? = @mode == :dashboard

    configure do
      # Templates are files in views/ (BT-137) - __END__ had grown to a
      # thousand lines, and every docs surface adds more. The gemspec must ship
      # *.erb, or the views 404 from the registry while working fine in a path
      # checkout (the troubleshooting.md failure class).
      set :views, File.expand_path('views', __dir__)
      disable :logging
      set :host_authorization, permitted_hosts: %w[localhost 127.0.0.1 ::1]
      # Compile templates once. This also used to guard a real corruption bug:
      # erubi escapes its input in place, and with inline __END__ templates the
      # input WAS the stored template, so every dev-mode recompile corrupted it
      # a little more (see BT-112 and the old transform_values! "fresh copy"
      # belt, removed with the inline registry in BT-137). A file-backed view is
      # re-read from disk per compile, so that failure mode is structurally gone
      # - this is now just the cheap setting.
      set :reload_templates, false
    end

    # Security headers on every response: forbid framing (clickjacking) and
    # content-sniffing (BT-116). For state-changing methods, reject a request
    # carrying a cross-origin Origin header - a page on another site can fire a
    # CORS-simple POST at localhost, but the browser always attaches its Origin,
    # so this blocks CSRF while leaving same-origin and non-browser (no Origin)
    # callers untouched (BT-085).
    before do
      headers 'X-Frame-Options'         => 'DENY',
              'X-Content-Type-Options'  => 'nosniff',
              'Content-Security-Policy' => "frame-ancestors 'none'"
      if %w[POST PUT DELETE].include?(request.request_method)
        origin = request.env['HTTP_ORIGIN']
        halt 403, json({ error: 'cross-origin request rejected' }) if origin && !permitted_origin?(origin)
      end
    end

    error do
      e = env['sinatra.error']
      warn "[BaconTracker] #{e.class}: #{e.message}"
      warn e.backtrace.first(10).join("\n")
      content_type :json
      status 500
      { error: 'Internal Server Error' }.to_json
    end

    helpers do
      def resolve_core
        if self.class.dashboard_mode?
          self.class.bt_dashboard&.project_core(params[:slug]) || halt(404, json({ error: 'Project not found' }))
        else
          halt(404, json({ error: 'Project not found' })) if request.path_info.start_with?('/projects/')
          self.class.bt_core || halt(503, json({ error: 'Not in single-project mode' }))
        end
      end

      # An Origin header is same-origin on localhost. rescue → nil host → rejected.
      def permitted_origin?(origin)
        host = begin
          URI(origin).host
        rescue URI::InvalidURIError
          nil
        end
        PERMITTED_ORIGIN_HOSTS.include?(host)
      end

      def h(text)
        Rack::Utils.escape_html(text.to_s)
      end

      def json_body
        len = request.content_length
        halt 413, json({ error: 'request body too large' }) if len && len.to_i > MAX_BODY_BYTES
        raw = request.body.read(MAX_BODY_BYTES + 1) || ''
        halt 413, json({ error: 'request body too large' }) if raw.bytesize > MAX_BODY_BYTES

        data = JSON.parse(raw)
        halt 400, json({ error: 'JSON body must be an object' }) unless data.is_a?(Hash)
        data
      rescue JSON::ParserError
        halt 400, json({ error: 'Invalid JSON body' })
      end

      def json(obj)
        content_type :json
        obj.to_json
      end

      # Internal-only story keys never serialized to clients.
      HIDDEN_KEYS = %i[dir declared_status].freeze

      def public_story(story)
        story.reject { |k, _| HIDDEN_KEYS.include?(k) }
      end

      def stories_json(c)
        # with_reverse_links adds the derived `blocks`/`linked_from` ends so the
        # board can show both sides of a relationship the frontmatter only stores
        # once (a file-based tracker can't write the far story).
        stories = c.with_reverse_links(c.all_stories)
        # Decisions citing each story (BT-148) - the reverse of the record's
        # stories: key, derived here for the same reason blocks/linked_from
        # are: a file-based tracker stores each relation on one side only.
        cited = Hash.new { |h, k| h[k] = [] }
        if c.config.decisions_root
          c.decisions_board.each { |r| r[:stories].each { |sid| cited[sid] << r[:id] } }
        end
        stories = stories.map { |st| st.merge(decisions: cited[st[:id]]) }
        by_stage = stories.group_by { |s| s[:stage] }
        # id => backlog position, so the backlog sort is O(1) per lookup rather
        # than order.index's O(n) scan inside sort_by (O(n^2) on the column) (BT-094).
        order_pos = c.backlog_ids.each_with_index.to_h

        # Sort on the trailing number, not the first digit run - a namespace
        # that itself contains a digit (e.g. "B2B") would otherwise key every
        # story on that digit and collapse the column ordering (BT-104).
        by_number = ->(s) { (s[:id][/(\d+)\z/] || '0').to_i }
        icebox  = (by_stage['1_icebox']  || []).sort_by(&by_number)
        backlog = (by_stage['2_backlog'] || []).sort_by { |s| order_pos[s[:id]] || 9999 }
        started = (by_stage['3_started'] || []).sort_by(&by_number)
        done    = (by_stage['4_done']    || []).sort_by(&by_number).reverse

        json({
          meta:    { tracker_root: c.config.tracker_root, backlog_path: c.config.backlog_path },
          icebox:  icebox.map  { |s| public_story(s) },
          backlog: backlog.map { |s| public_story(s) },
          started: started.map { |s| public_story(s) },
          done:    done.map    { |s| public_story(s) }
        })
      end
    end

    # ── Static client assets (served globally; the JS uses window.BT_API_BASE
    #    for API calls, so one copy works in both single and dashboard mode) ──
    get '/decisions.js' do
      content_type 'application/javascript'
      DECISIONS_JS
    end

    get '/docs.js' do
      content_type 'application/javascript'
      DOCS_JS
    end

    get '/app.js' do
      content_type 'application/javascript'
      APP_JS
    end

    get '/theme.js' do
      content_type 'application/javascript'
      THEME_JS
    end

    get '/logic.js' do
      content_type 'application/javascript'
      LOGIC_JS
    end

    # ── Dashboard index ────────────────────────────────────────────────────────

    get '/' do
      if self.class.dashboard_mode?
        @project_stats = self.class.bt_dashboard.project_stats
        erb :dashboard
      else
        @namespace = resolve_core.config.namespace
        @api_base  = ''
        erb :index
      end
    end

    # ── Per-project board (dashboard mode) ───────────────────────────────────

    get '/projects/:slug' do
      slug = params[:slug]
      proj = self.class.bt_dashboard&.projects&.find { |p| p.slug == slug }
      halt 404, 'Project not found' unless proj
      @namespace    = proj.namespace
      @project_name = proj.name
      @api_base     = "/projects/#{slug}"
      @show_back    = true
      erb :index
    end

    # ── Stats (consumed by BaconTrackerMenu) ─────────────────────────────────

    get '/api/stats' do
      if self.class.dashboard_mode?
        json(self.class.bt_dashboard.project_stats)
      else
        c = resolve_core
        s = c.stats
        # slug is nil in single mode (there is no /projects/:slug board) but
        # the key is always present so both modes share one response shape.
        json([s.merge(name: c.config.namespace, namespace: c.config.namespace, slug: nil)])
      end
    end

    # ── Reveal in the file manager ───────────────────────────────────────────

    scoped('/api/reveal').each do |pat|
      post pat do
        raw = json_body['path'].to_s
        halt 400, json({ error: 'path required' }) if raw.empty?
        path = File.expand_path(raw)
        # Scope to THIS request's project only - resolve_core honors :slug in
        # dashboard mode, so one project's reveal endpoint can't reach another
        # project's files (BT-085). A project now has more than one root
        # (BT-ADR-0016), so the test is "inside ANY of this project's roots" -
        # widened, not loosened. The separator matters: without it, a root of
        # /a/tracker would also admit /a/tracker-evil.
        roots = resolve_core.config.roots
        inside = roots.any? { |r| path == r || path.start_with?(r + File::SEPARATOR) }
        halt 400, json({ error: 'path is outside tracked directories' }) unless inside
        target = File.exist?(path) ? path : File.dirname(path)
        begin
          Launcher.run(Launcher.reveal_argv(target))
        rescue Launcher::Unavailable => e
          halt 501, json({ error: e.message })
        end
        json({ ok: true })
      end
    end

    # ── Stories API ───────────────────────────────────────────────────────────

    scoped('/api/stories').each do |pat|
      get pat do
        stories_json(resolve_core)
      end

      post pat do
        data  = json_body
        story = resolve_core.create_story(data['type'], data['title'],
                                          stage: data['stage'] || '1_icebox',
                                          size:  data['size'])
        status 201
        json(public_story(story)) # full Story incl. path, matching GET/PUT (BT-089)
      rescue ArgumentError => e
        status 400; json({ error: e.message })
      end
    end

    scoped('/api/stories/backlog/order').each do |pat|
      put pat do
        resolve_core.backlog_reorder(json_body['ids'])
        json({ ok: true })
      rescue ArgumentError, TypeError => e
        status 400; json({ error: e.message })
      end
    end

    scoped('/api/stories/:id/stage').each do |pat|
      put pat do
        resolve_core.set_stage(params[:id], json_body['stage'])
        json({ ok: true })
      rescue ArgumentError => e
        status 400; json({ error: e.message })
      end
    end

    # ── Docs surface (BT-138; the browser itself is BT-139) ─────────────────
    scoped('/docs').each do |pat|
      get pat do
        core = resolve_core
        halt 404, 'no docs surface' unless core.config.docs_root && Dir.exist?(core.config.docs_root)

        @doc_stats = core.docs_stats
        @doc_title = if self.class.dashboard_mode?
                       self.class.bt_dashboard.projects.find { |p| p.slug == params[:slug] }&.name
                     end || core.config.namespace
        @doc_slug  = params[:slug]
        erb :docs
      end
    end

    scoped('/api/docs/search').each do |pat|
      get pat do
        json resolve_core.docs_search(params[:q])
      end
    end

    scoped('/api/docs/recent').each do |pat|
      get pat do
        json resolve_core.docs_recent
      end
    end

    scoped('/api/docs/backlinks').each do |pat|
      get pat do
        json resolve_core.docs_backlinks(params[:path].to_s)
      end
    end

    scoped('/api/docs/front').each do |pat|
      get pat do
        json resolve_core.project_front
      end
    end

    scoped('/api/docs/tree').each do |pat|
      get pat do
        json resolve_core.docs_tree
      end
    end

    scoped('/api/docs/page').each do |pat|
      get pat do
        json resolve_core.render_page(params[:path])
      rescue ArgumentError => e
        status 400
        json({ error: e.message })
      end
    end

    # Act on the real file (BT-142, BT-143). Same scope check as the page
    # read; the launch mirrors /api/reveal - fire and detach, and a missing
    # launcher is a 501 with the reason rather than a false ok.
    %w[editor reveal].each do |action|
      scoped("/api/docs/#{action}").each do |pat|
        post pat do
          target = resolve_core.docs_file!(json_body['path'].to_s, allow_dir: action == 'reveal')
          argv = action == 'editor' ? Launcher.open_argv(target) : Launcher.reveal_argv(target)
          begin
            Launcher.run(argv)
          rescue Launcher::Unavailable => e
            halt 501, json({ error: e.message })
          end
          json({ ok: true })
        rescue ArgumentError => e
          status 400
          json({ error: e.message })
        end
      end
    end

    scoped('/api/decisions/proposed/order').each do |pat|
      put pat do
        resolve_core.proposed_reorder(json_body['ids'])
        json({ ok: true })
      rescue ArgumentError => e
        status 400
        json({ error: e.message })
      end
    end

    scoped('/api/decisions').each do |pat|
      get pat do
        json resolve_core.decisions_board
      end

      post pat do
        path = resolve_core.create_decision(json_body['title'])
        json({ ok: true, path: File.basename(path) })
      rescue ArgumentError => e
        status 400
        json({ error: e.message })
      end
    end

    scoped('/docs/decisions').each do |pat|
      get pat do
        core = resolve_core
        halt 404, 'no decisions' unless core.config.decisions_root && Dir.exist?(core.config.decisions_root)

        @doc_title = if self.class.dashboard_mode?
                       self.class.bt_dashboard.projects.find { |p| p.slug == params[:slug] }&.name
                     end || core.config.namespace
        @doc_slug = params[:slug]
        erb :decisions
      end
    end

    # ── Decisions API (BT-135 / BT-ADR-0017) ─────────────────────────────────
    # One transition endpoint mirroring the stage route. Validation is the
    # primitive's: a missing or unresolvable supersede target is a 400, never a
    # 200 with a partial write.
    scoped('/api/decisions/:id/status').each do |pat|
      put pat do
        body = json_body
        begin
          result = resolve_core.set_status(params[:id], body['status'].to_s,
                                           superseded_by: body['superseded_by'])
          json result
        rescue ArgumentError => e
          halt 400, json({ error: e.message })
        end
      end
    end

    scoped('/api/stories/:id/subtasks').each do |pat|
      put pat do
        data   = json_body
        counts = resolve_core.toggle_subtask(params[:id], data['index'], data['done'])
        json({ ok: true, subtasks: counts })
      rescue ArgumentError => e
        status 400; json({ error: e.message })
      end
    end

    scoped('/api/stories/:id').each do |pat|
      put pat do
        data = json_body
        core = resolve_core
        core.update_story(params[:id], title: data['title'], body: data['body'],
                                       size: data['size'], blocked_by: data['blocked_by'],
                                       linked_to: data['linked_to'], assignee: data['assignee'])
        # Return the re-parsed story so the client gets fresh derived fields
        # (subtasks, subtask_lines, path after a rename) without a refetch. The
        # re-read runs after update_story's lock released, so guard against the
        # story having been deleted/renamed out from under us - a nil here would
        # otherwise NoMethodError into a 500 instead of a clean 404 (BT-080).
        result = core.find_story(params[:id])
        story  = result && core.parse_story_file(result[:file], result)
        halt 404, json({ error: "Story #{params[:id]} not found." }) unless story
        json(public_story(story))
      rescue ArgumentError => e
        status 400; json({ error: e.message })
      end

      delete pat do
        resolve_core.delete_story(params[:id])
        json({ ok: true })
      rescue ArgumentError => e
        status 400; json({ error: e.message })
      end
    end
  end
end
