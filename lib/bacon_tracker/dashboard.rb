module BaconTracker
  class Dashboard
    Project = Struct.new(:name, :slug, :path, :namespace, :tracker_root, :docs_root, :version_path,
                         keyword_init: true) do
      # A surface exists if its directory does. Absent means "this project has
      # none" - not an error (BT-ADR-0016).
      def tracker? = Dir.exist?(tracker_root.to_s)
      def docs?    = Dir.exist?(docs_root.to_s)

      # Derived, never configured: a repo that keeps its tracker inside its docs
      # tree still works, the docs surface just skips it. Both paths are already
      # known, so there is nothing to ask twice.
      def tracker_inside_docs?
        return false unless tracker_root && docs_root

        tracker_root.start_with?(docs_root + File::SEPARATOR)
      end
    end

    def initialize(path)
      @path = path
    end

    # Re-parses when dashboard.md's mtime changes, so edits apply without
    # restarting the server.
    def projects
      mtime = begin
        File.mtime(@path)
      rescue Errno::ENOENT
        nil
      end
      if @projects.nil? || mtime != @parsed_mtime
        @projects     = parse
        @parsed_mtime = mtime
      end
      @projects
    end

    def project_core(slug)
      proj = projects.find { |p| p.slug == slug }
      proj && core_for(proj)
    end

    def project_stats
      projects.map do |proj|
        core = core_for(proj)
        core.stats
            .merge(core.docs_stats)
            .merge(name: proj.name, slug: proj.slug, namespace: proj.namespace,
                   tracker: proj.tracker?, docs: proj.docs?,
                   # resolve_version alone - project_front would also render
                   # README and CHANGELOG on every stats poll (BT-179).
                   version: core.resolve_version(proj.path).first)
      end
    end

    # The one place a registry entry becomes a Configuration. The server and
    # the Rake tasks both go through it, so they cannot disagree about which
    # directory holds the stories (BT-179: the tasks used to take the project
    # root for the tracker root and write stories beside tracker/ instead of
    # inside it).
    def config_for(proj)
      config = Configuration.new
      config.namespace    = proj.namespace
      config.tracker_root = proj.tracker_root
      config.project_root = proj.path
      config.version_path = proj.version_path
      if proj.docs?
        config.docs_root      = proj.docs_root
        config.decisions_root = File.join(proj.docs_root, 'decisions')
      end
      config
    end

    private

    def core_for(proj)
      Core.new(config_for(proj))
    end

    def parse
      return [] unless File.exist?(@path)

      entries = []
      current = nil

      # Explicit UTF-8: the locale default (US-ASCII under LANG=C, the norm in
      # containers and CI) raises on a non-ASCII project name (BT-179).
      File.foreach(@path, encoding: 'utf-8') do |raw|
        line = raw.scrub
        if (m = line.match(/^## (.+)/))
          entries << current if current
          current = { name: m[1].strip, attrs: {} }
        elsif current && (m = line.match(/^(\w+):\s*(.+)/))
          current[:attrs][m[1]] = m[2].strip
        end
      end
      entries << current if current

      # build_project warns and returns nil for an unusable entry (no path, or a
      # name that yields an empty namespace) instead of dropping it silently or
      # building a broken project (BT-086).
      results = entries.filter_map { |e| build_project(e) }

      # Colliding slugs would route every request to the first match - suffix
      # later duplicates so each project keeps a working board.
      seen = Hash.new(0)
      results.each do |p|
        n = (seen[p.slug] += 1)
        p.slug = "#{p.slug}-#{n}" if n > 1
      end

      results
    end

    def tracker_dir?(dir)
      File.exist?(File.join(dir, 'backlog.md')) || File.exist?(File.join(dir, '.next-id'))
    end

    # An absent default root is silent - the project simply has no such surface.
    # An explicit key that resolves nowhere is a typo and warns, the same way a
    # missing 'path:' does (BT-ADR-0016).
    def resolve_root(item, key, default, path)
      given = item[:attrs][key]
      root  = File.expand_path(given || default, path)
      if given && !Dir.exist?(root)
        warn "[BaconTracker] dashboard.md: #{item[:name].inspect} sets #{key}: #{given.inspect}, " \
             "which does not exist (#{root})"
      end
      root
    end

    def build_project(item)
      unless item[:attrs]['path']
        warn "[BaconTracker] dashboard.md: skipping project #{item[:name].inspect} - no 'path:'"
        return nil
      end

      slug      = BaconTracker.slugify(item[:name])
      namespace = item[:attrs]['namespace'] || slug.upcase.gsub('-', '_')
      if namespace.empty?
        warn "[BaconTracker] dashboard.md: skipping project #{item[:name].inspect} - " \
             "empty namespace (its name has no letters/digits; add an explicit 'namespace:')"
        return nil
      end

      # Relative paths are relative to dashboard.md, not the process CWD.
      path = File.expand_path(item[:attrs]['path'], File.dirname(@path))

      # Compatibility (BT-134): a registry written before BT-ADR-0016 points
      # 'path:' straight at the tracker directory. Detect that - a directory
      # holding backlog.md or .next-id IS the tracker root - rather than
      # silently showing an empty board, which is this codebase's worst failure
      # mode. An explicit 'tracker:' always wins.
      legacy = item[:attrs]['tracker'].nil? && tracker_dir?(path)

      Project.new(
        name:         item[:name],
        slug:         slug,
        path:         legacy ? File.dirname(path) : path,
        namespace:    namespace,
        version_path: item[:attrs]['version'],
        tracker_root: legacy ? path : resolve_root(item, 'tracker', 'tracker', path),
        docs_root:    resolve_root(item, 'docs', 'docs', legacy ? File.dirname(path) : path)
      )
    end
  end
end
