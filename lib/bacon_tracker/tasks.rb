module BaconTracker
  module Tasks
    extend Rake::DSL

    # Parse the server port from $PORT, failing loudly on a non-integer instead
    # of String#to_i silently yielding 0 and binding a random port (BT-087).
    def self.env_port
      Integer(ENV.fetch('PORT', '4567'))
    rescue ArgumentError
      abort "PORT must be an integer, got: #{ENV['PORT'].inspect}"
    end

    # 1-indexed line number of the first line matching `re`, or nil. Used to
    # anchor a GitHub annotation to the offending frontmatter line rather than
    # to the top of the file; nil is fine, the annotation just lands file-wide.
    def self.line_matching(path, re)
      return nil unless path && File.file?(path)

      File.foreach(path).with_index(1) { |line, n| return n if line.match?(re) }
      nil
    rescue SystemCallError
      nil
    end

    # A GitHub Actions workflow command, so a finding renders as an annotation
    # on the file that caused it. Errors fail the check; flow signals are
    # notices, which annotate without failing - the same severity split the
    # terminal output makes (BT-121/BT-123).
    #
    # Paths must be workspace-relative or GitHub will not match them to the
    # diff. The message and property values are escaped per GitHub's rules:
    # messages escape %/CR/LF, properties additionally escape , and :.
    def self.github_annotation(finding)
      esc  = ->(s) { s.to_s.gsub('%', '%25').gsub("\r", '%0D').gsub("\n", '%0A') }
      prop = ->(s) { esc.call(s).gsub(',', '%2C').gsub(':', '%3A') }

      props = []
      if (rel = relative_path(finding[:path]))
        props << "file=#{prop.call(rel)}"
        props << "line=#{finding[:line]}" if finding[:line]
      end
      command = finding[:severity] == :notice ? 'notice' : 'error'
      "::#{command}#{props.empty? ? '' : " #{props.join(',')}"}::#{esc.call(finding[:text])}"
    end

    # Path relative to the workspace GitHub checked out (falling back to the
    # working directory), since annotations are matched against repo-relative
    # paths. Returns nil for a path outside it - better no `file=` than a wrong
    # one, which would annotate an unrelated file.
    def self.relative_path(path)
      return nil unless path

      root = File.expand_path(ENV.fetch('GITHUB_WORKSPACE', Dir.pwd))
      full = File.expand_path(path)
      return nil unless full.start_with?("#{root}/")

      full.delete_prefix("#{root}/")
    end

    # One line per relationship finding (BT-121). Each says what is wrong and,
    # where there is an obvious next move, what to do about it - a lint line
    # nobody knows how to act on is a lint line people learn to skip.
    def self.relationship_message(finding)
      id, ref = finding[:id], finding[:ref]
      case finding[:kind]
      when :stale_blocker
        "stale-blocker: #{id} waits on #{ref}, which is done - clear it from blocked_by"
      when :dangling
        "dangling-ref: #{id} #{finding[:field]} names #{ref}, which has no story file"
      when :cycle
        chain = (finding[:cycle] + [finding[:cycle].first]).join(' → ')
        "cycle: #{chain} - none of these can ever start"
      when :started_while_blocked
        "blocked-started: #{id} is started but waits on #{ref} (#{finding[:ref_stage]})"
      end
    end

    def self.install_for_dashboard(dashboard_path)
      require 'bacon_tracker/dashboard'

      dashboard = BaconTracker::Dashboard.new(dashboard_path)
      ns = ENV['NS'] || ENV['NAMESPACE']

      # Without NS the per-project story tasks can't be targeted, but rake
      # itself must keep working (rake -T, story:dashboard_server) - aborting
      # here would kill every rake invocation at Rakefile-load time.
      unless ns
        install_dashboard_server_task(dashboard_path)
        return
      end

      proj = dashboard.projects.find { |p| p.namespace.casecmp(ns) == 0 }
      unless proj
        list = dashboard.projects.map { |p| "#{p.namespace} (#{p.name})" }.join(', ')
        abort "No project with namespace '#{ns}'.\n  Available: #{list}"
      end

      # Same Configuration the server builds for this project - tracker, docs
      # and decisions roots included - so `rake story:*` and the board always
      # read and write the same directories (BT-179).
      BaconTracker.instance_variable_set(:@config, dashboard.config_for(proj))

      install
      install_dashboard_server_task(dashboard_path) # install's copy has no path
    end

    def self.install_version_tasks
      version_file = File.expand_path('../bacon_tracker/version.rb', __dir__)

      # Same replace-don't-stack rule as install (BT-057) - a doubled bump
      # task would bump the version twice per invocation.
      Rake.application.tasks.each { |t| t.clear if t.name.start_with?('version:') }

      namespace :version do
        desc 'Print the current gem version'
        task :current do
          require 'bacon_tracker/version'
          puts BaconTracker::VERSION
        end

        %w[patch minor major].each do |level|
          desc "Bump #{level} version in lib/bacon_tracker/version.rb"
          task level do
            content = File.read(version_file)
            current = content[/VERSION = "(\d+\.\d+\.\d+)"/, 1]
            abort "Could not read VERSION from #{version_file}" unless current
            parts = current.split('.').map(&:to_i)
            case level
            when 'patch' then parts[2] += 1
            when 'minor' then parts[1] += 1; parts[2] = 0
            when 'major' then parts[0] += 1; parts[1] = 0; parts[2] = 0
            end
            new_version = parts.join('.')
            File.write(version_file, content.sub(/VERSION = "#{Regexp.escape(current)}"/, %(VERSION = "#{new_version}")))
            puts "#{current} → #{new_version}"
          end
        end

        desc 'Tag HEAD as the current version and push the tag'
        task :release do
          require 'bacon_tracker/version'
          tag = "v#{BaconTracker::VERSION}"
          # Refuse to tag a dirty tree: BaconTracker::VERSION is read from the
          # working copy, so an uncommitted `version:patch` would tag a HEAD
          # whose committed version.rb still says the old number (BT-110).
          unless `git status --porcelain`.strip.empty?
            abort "Working tree is dirty - commit the version bump before releasing #{tag}."
          end
          system('git', 'tag', tag) || abort('git tag failed')
          system('git', 'push', 'origin', tag) || abort('git push failed')
          puts "Released #{tag}"
        end
      end
    end

    def self.install
      # Re-install replaces earlier story tasks - repeated installs used to
      # stack duplicate actions (Rake appends on redefinition). The config is
      # snapshotted so later configure calls can't retarget installed tasks.
      Rake.application.tasks.each { |t| t.clear if t.name.start_with?('story:', 'decision:') }
      core = BaconTracker::Core.new(BaconTracker.config.dup)
      ns   = core.config.namespace

      namespace :decision do
        desc "Create a proposed decision from the template: rake \"decision:new[My decision]\""
        task :new, [:title] do |_, args|
          path = core.create_decision(args[:title])
          puts "#{File.basename(path, '.md')[/\A[A-Z][A-Z0-9]*-ADR-\d+/]} → #{path}"
        rescue ArgumentError => e
          abort e.message
        end

        desc "Accept a proposed decision: rake \"decision:accept[#{ns}-ADR-0001]\""
        task :accept, [:id] do |_, args|
          core.transition_decision(args[:id], 'accepted')
        end

        desc "Reject a proposed decision: rake \"decision:reject[#{ns}-ADR-0001]\""
        task :reject, [:id] do |_, args|
          core.transition_decision(args[:id], 'rejected')
        end

        desc "Deprecate an accepted decision: rake \"decision:deprecate[#{ns}-ADR-0001]\""
        task :deprecate, [:id] do |_, args|
          core.transition_decision(args[:id], 'deprecated')
        end

        desc "Supersede an accepted decision - the second argument is required: rake \"decision:supersede[#{ns}-ADR-0001,#{ns}-ADR-0002]\""
        task :supersede, [:id, :by] do |_, args|
          core.transition_decision(args[:id], 'superseded', superseded_by: args[:by])
        end

        desc 'Check the decision records: frontmatter, status vs directory, ids, supersession, proposed.md'
        task :lint do
          unless core.config.decisions_root
            puts 'No decisions_root configured - nothing to lint.'
            next
          end

          findings = core.decision_findings
          failures = findings.select { |f| f[:severity] == :failure }
          warnings = findings.select { |f| f[:severity] == :warning }

          if findings.empty?
            puts "Decisions are clean - #{core.decisions.size} records."
            next
          end

          failures.each { |f| puts "  #{f[:kind]}: #{[f[:id], f[:message]].compact.join(' - ')}" }
          warnings.each { |f| puts "  warning #{f[:kind]}: #{[f[:id], f[:message]].compact.join(' - ')}" }
          puts
          puts "#{failures.size} failure(s), #{warnings.size} warning(s) over #{core.decisions.size} records."

          # Severity split follows BT-ADR-0013: integrity fails the build,
          # hygiene reports and exits clean.
          abort 'Decision lint failed.' if failures.any?
        end
      end

      namespace :story do
        # Parse trailing field=value tokens (size/assignee/blocked_by/linked_to/title/body)
        # into update_story kwargs, aborting cleanly on an unknown field. Shared
        # by the create tasks and story:edit.
        parse_fields = lambda do |extras|
          core.edit_assignments(extras)
        rescue ArgumentError => e
          abort e.message
        end

        desc "Create a feature in features/1_icebox, optional fields: rake \"story:feature[My Title,size=M,assignee=AB]\""
        task :feature, [:title] do |_, args|
          abort "Usage: rake \"story:feature[My title[,size=M,assignee=AB]]\"" if args[:title].nil?
          core.create('feature', args[:title], parse_fields.call(args.extras))
        end

        desc "Create a bug in bugs/1_icebox, optional fields: rake \"story:bug[My Title,size=S]\""
        task :bug, [:title] do |_, args|
          abort "Usage: rake \"story:bug[My title[,size=M,assignee=AB]]\"" if args[:title].nil?
          core.create('bug', args[:title], parse_fields.call(args.extras))
        end

        desc "Create a chore in chores/1_icebox, optional fields: rake \"story:chore[My Title,assignee=AB]\""
        task :chore, [:title] do |_, args|
          abort "Usage: rake \"story:chore[My title[,size=M,assignee=AB]]\"" if args[:title].nil?
          core.create('chore', args[:title], parse_fields.call(args.extras))
        end

        desc "Move a story from 1_icebox to 2_backlog and add to backlog.md (commit to it): rake \"story:commit[#{ns}-001]\""
        task :commit, [:story_id] do |_, args|
          id = args[:story_id]&.strip
          abort "Usage: rake \"story:commit[#{ns}-001]\"" if id.nil?
          core.commit(id)
        end

        desc "Move a story from 2_backlog to 3_started (start work on it): rake \"story:start[#{ns}-001]\""
        task :start, [:story_id] do |_, args|
          id = args[:story_id]&.strip
          abort "Usage: rake \"story:start[#{ns}-001]\"" if id.nil?
          core.start(id)
        end

        desc "Move a story to 4_done and remove from backlog.md: rake \"story:done[#{ns}-001]\""
        task :done, [:story_id] do |_, args|
          id = args[:story_id]&.strip
          abort "Usage: rake \"story:done[#{ns}-001]\"" if id.nil?
          core.done(id)
        end

        desc "Set story fields (size/assignee/blocked_by/linked_to/title/body): rake \"story:edit[#{ns}-001,size=M,assignee=AB]\""
        task :edit, [:story_id] do |_, args|
          id = args[:story_id]&.strip
          abort "Usage: rake \"story:edit[#{ns}-001,size=M,assignee=AB]\"" if id.nil?
          kwargs = parse_fields.call(args.extras)
          abort "No fields given. Example: rake \"story:edit[#{ns}-001,size=M]\"" if kwargs.empty?
          warn "Note: body= replaces the entire body of #{id}." if kwargs.key?(:body)
          begin
            core.update_story(id, **kwargs)
            puts "Updated #{id}: #{kwargs.keys.join(', ')}"
          rescue ArgumentError => e
            abort e.message
          end
        end

        desc 'Print the top item in backlog.md'
        task :next do
          lines = core.backlog_lines
          abort 'Backlog is empty.' if lines.empty?
          puts lines.first.strip
        end

        desc 'Check backlog.md against 2_backlog story files for drift, flag duplicate IDs across stages, check blocked_by/linked_to, and verify .next-id'
        task :lint do
          listed   = core.backlog_ids
          on_disk  = core.backlog_story_files.filter_map { |f| File.basename(f)[core.filename_id_pattern] }
          phantom  = listed - on_disk
          unlisted = on_disk - listed
          dupes    = core.duplicate_id_stages
          drift    = core.status_drift
          max_id   = core.max_story_id
          next_id  = core.next_id_value
          stale_id = next_id <= max_id

          rel = core.relationship_findings
          rel_warn, rel_err = rel.partition { |f| BaconTracker::Core::RELATIONSHIP_WARNINGS.include?(f[:kind]) }

          # Flow signals (rel_warn) are reported but never fail the build: a
          # started story waiting on a blocker is a legitimate state per
          # docs/flow.md, so failing CI on it would train people to ignore lint.
          broken = !(phantom.empty? && unlisted.empty? && dupes.empty? && drift.empty? && rel_err.empty?) || stale_id

          if !broken && rel_warn.empty?
            puts "Backlog is clean - #{listed.size} stories."
          else
            # One list, two renderings. Each entry carries the text (identical
            # to what the terminal has always printed) plus where it came from,
            # so LINT_FORMAT=github can anchor an annotation to the offending
            # file and line instead of burying it in a log.
            findings = []
            add = ->(text, path, line = nil, severity = :error) do
              findings << { text: text, path: path, line: line, severity: severity }
            end

            backlog = core.config.backlog_path
            phantom.each do |id|
              add.call("phantom:  #{id} in backlog.md but no file in 2_backlog/",
                       backlog, BaconTracker::Tasks.line_matching(backlog, /\b#{Regexp.escape(id)}\b/))
            end
            unlisted.each do |id|
              # Anchored to the story file, not backlog.md: the pull request
              # that forgot the backlog line is the one that added this file,
              # so this is the side that appears in the diff.
              add.call("unlisted: #{id} has file in 2_backlog/ but missing from backlog.md",
                       core.backlog_story_files.find { |f| File.basename(f).start_with?(id) } || backlog)
            end
            dupes.each do |id, paths|
              text = "duplicate: #{id} found in #{paths.map { |p| p.sub("#{core.config.tracker_root}/", '') }.join(' and ')}"
              paths.each { |dup| add.call(text, dup) }
            end
            drift.each do |d|
              path = d[:path]
              add.call("status-drift: #{d[:id]} frontmatter says '#{d[:declared]}' but the file lives in the #{d[:actual]} stage dir",
                       path, BaconTracker::Tasks.line_matching(path, /^#?\s*status:/))
            end
            if stale_id
              add.call("stale-id: .next-id is #{next_id} but the highest story is #{core.format_id(max_id)} - expected #{max_id + 1}",
                       core.config.next_id_path)
            end
            (rel_err + rel_warn).each do |f|
              field = f[:kind] == :dangling ? f[:field] : 'blocked_by'
              add.call(BaconTracker::Tasks.relationship_message(f), f[:path],
                       BaconTracker::Tasks.line_matching(f[:path], /^#?\s*#{field}:/),
                       BaconTracker::Core::RELATIONSHIP_WARNINGS.include?(f[:kind]) ? :notice : :error)
            end

            if ENV['LINT_FORMAT'] == 'github'
              # Duplicates share one text across two files; each still gets its
              # own annotation, but say it once per file, not once per pairing.
              findings.uniq { |f| [f[:text], f[:path]] }
                      .each { |f| puts BaconTracker::Tasks.github_annotation(f) }
            else
              findings.uniq { |f| f[:text] }.each { |f| warn "  #{f[:text]}" }
            end
            puts 'No integrity problems - the note above is a flow signal, not a failure.' if !broken && rel_warn.any?
            exit 1 if broken
          end
        end

        desc 'Start the tracker board on http://localhost:4567'
        task :server do
          require 'bacon_tracker/server'
          port = BaconTracker::Tasks.env_port
          puts "Bacon Tracker running at http://localhost:#{port}"
          puts 'Ctrl-C to stop.'
          BaconTracker::Server.boot(core.config).run!(port: port, bind: 'localhost', quiet: true)
        end

        desc "Assign #{ns} IDs to all existing stories (oldest git commit first)"
        task :migrate do
          first_commits = core.git_first_commit_times
          all_files = core.story_dirs.flat_map do |d|
            core.safe_glob(d[:path], '*.{md,feature}').filter_map do |f|
              next if File.basename(f).start_with?('_')
              next if core.already_migrated?(f)

              content = File.read(f, encoding: 'utf-8')
              # Skip a file that already carries a frontmatter block (but no ID
              # in its name) - prepending again would double the frontmatter and
              # bury the old block in the body (BT-105).
              next if content.start_with?("---\n") || content.match?(/\A# \w+:/)

              relative = f.sub("#{core.config.tracker_root}/", '')
              d.merge(file: f, content: content, ts: first_commits[relative] || File.mtime(f).to_i)
            end
          end

          all_files.sort_by! { |f| [f[:ts], f[:file]] }

          if all_files.empty?
            puts 'Nothing to migrate - all stories already have IDs.'
            next
          end

          all_files.each do |info|
            path   = info[:file]
            ext    = File.extname(path)
            base   = File.basename(path, ext)
            status = BaconTracker::STATUS_MAP[info[:stage]]
            id     = core.format_id(core.consume_id)

            new_name = "#{id}-#{base}#{ext}"
            new_path = File.join(File.dirname(path), new_name)

            new_content = if ext == '.feature'
                            core.frontmatter_feature(id, info[:type], status) + info[:content]
                          else
                            core.frontmatter_md(id, info[:type], status) + info[:content]
                          end

            File.write(new_path, new_content)
            File.delete(path) unless path == new_path
            puts "  #{File.basename(path)} -> #{new_name}"
          end

          # Renamed 2_backlog files got new IDs - reconcile backlog.md so they're
          # listed (lint reported them 'unlisted' before) instead of leaving the
          # backlog inconsistent (BT-105).
          core.heal_backlog!
          puts "\nMigrated #{all_files.size} stories. Next ID: #{core.format_id(core.next_id_value)}"
          puts 'backlog.md reconciled - review it for any pre-migration lines without an ID.'
        end
      end

      install_dashboard_server_task
    end

    # NS-independent: the dashboard server serves every project, so it is
    # installed even when no NS is set.
    # `default_path` is the dashboard the Rakefile names; $DASHBOARD still wins,
    # then ./dashboard.md. Without it the task only worked from the Rakefile's
    # own directory (BT-179).
    def self.install_dashboard_server_task(default_path = nil)
      Rake.application.tasks.each { |t| t.clear if t.name == 'story:dashboard_server' }

      namespace :story do
        desc 'Start the centralized dashboard server (reads dashboard.md): rake story:dashboard_server'
        task :dashboard_server do
          require 'bacon_tracker/server'
          require 'bacon_tracker/dashboard'

          dashboard_path = ENV['DASHBOARD'] || default_path || File.join(Dir.pwd, 'dashboard.md')
          abort "dashboard.md not found at #{dashboard_path}\n\nCreate it with:\n\n  ## My Project\n  path: /path/to/my-project   # holds tracker/ (and docs/ if you have one)\n  namespace: MYP\n" unless File.exist?(dashboard_path)

          dashboard = BaconTracker::Dashboard.new(dashboard_path)
          abort "No projects found in #{dashboard_path}" if dashboard.projects.empty?

          port = BaconTracker::Tasks.env_port
          puts "Bacon Dashboard running at http://localhost:#{port}"
          puts "Projects: #{dashboard.projects.map(&:name).join(', ')}"
          puts 'Ctrl-C to stop.'
          BaconTracker::Server.boot_dashboard(dashboard).run!(port: port, bind: 'localhost', quiet: true)
        end
      end
    end
  end
end
