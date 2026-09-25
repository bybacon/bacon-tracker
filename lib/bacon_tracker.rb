require 'set'
require 'shellwords'
require 'fileutils'
require 'yaml'
require 'date'
require 'kramdown'
require 'kramdown-parser-gfm'

module BaconTracker
  STORY_DIRS = {
    'features' => { type: 'feature', ext: '.feature' },
    'bugs'     => { type: 'bug', ext: '.md' },
    'chores'   => { type: 'chore', ext: '.md' }
  }.freeze

  STAGES = %w[1_icebox 2_backlog 3_started 4_done].freeze

  # Decision statuses (BT-ADR-0014). Unlike stages these are not a linear flow:
  # `proposed` and `accepted` are non-terminal, the other three are outcomes.
  # The directory named for a status is the source of truth for it.
  STATUSES = %w[proposed accepted rejected deprecated superseded].freeze

  STATUS_MAP = {
    '1_icebox'  => 'icebox',
    '2_backlog' => 'backlog',
    '3_started' => 'started',
    '4_done'    => 'done'
  }.freeze

  # Bundled Claude slash commands that tracker-init installs for the user.
  COMMANDS_DIR = File.expand_path('bacon_tracker/commands', __dir__).freeze

  # Default story templates - single source for tracker-init's _template files
  # and Core#create_story's no-template fallback.
  module Templates
    FEATURE = <<~GHERKIN.freeze
      Feature: Name the Feature

        Scenario: Happy path
          Given a starting condition
          When an action is performed
          Then the expected outcome occurs

      # Subtasks (optional): add "- [ ] a step" lines below to track progress -
      # the board counts them and lets you tick them off.
    GHERKIN

    def self.markdown(type_name)
      <<~MD
        Title: #{type_name.capitalize} Title

        ## Description

        <!-- Describe the #{type_name.downcase} here -->

        ## Acceptance Criteria

        <!-- Add "- [ ] a step" lines here - the board counts them and lets you
             tick them off. (No live checkbox ships in the template, so a new
             story starts with zero subtasks rather than a phantom 0/1 - BT-108.) -->
      MD
    end

    # The decision record template (BT-ADR-0014) - single source for
    # tracker-init's scaffolding, so a new project starts contract-conforming.
    DECISION = <<~MD.freeze
      ---
      status: proposed
      date: 2026-01-01
      ---

      # Name the decision

      - Date: 2026-01-01
      - Related: -

      ## Status

      Proposed

      ## Context

      What is the issue that we're seeing that is motivating this decision?

      ## Decision

      What is the change that we're proposing and/or doing?

      ## Consequences

      What becomes easier or more difficult because of this change? Record the
      costs as plainly as the benefits.

      <!--
      Filename: <NS>-ADR-NNNN-slug.md, in the directory named for its status.
      Take NNNN from .next-id. `status` must match that directory; `date` is the
      day the decision took effect, ISO-8601 - replace the placeholder.

      `status` and `date` are the only required keys. Add deciders, supersedes,
      superseded_by, stories, canonical or tags only when they have a value.

      An accepted record is immutable - append "## Amendment - YYYY-MM-DD (STORY)",
      or supersede it with a new one.
      -->
    MD

    def self.for(ext, type_name)
      ext == '.feature' ? FEATURE : markdown(type_name)
    end
  end

  class Configuration
    # tracker_root holds the stories; docs_root holds the prose and decisions_root
    # the ADRs beneath it. They are
    # separate because a project's stories and its decisions need not share a
    # checkout - a product-wide tracker can sit in a parent repo while each
    # repo keeps its own decisions (BT-ADR-0016, BT-167). decisions_root is nil
    # until set.
    # project_root anchors the identity files (README, CHANGELOG, VERSION);
    # version_path overrides the VERSION search when a project keeps it
    # somewhere the fixed order cannot see (BT-149, BT-162).
    attr_accessor :namespace, :version_path
    attr_reader   :tracker_root, :docs_root, :decisions_root, :project_root

    def initialize
      @namespace = 'BCN'
    end

    # Roots are expanded on assignment: a Rakefile's `~/proj/tracker` would
    # otherwise be a literal directory named `~` under the CWD, and every
    # Dir.exist? check would report the real tracker as absent (BT-179).
    %i[tracker_root docs_root decisions_root project_root].each do |root|
      define_method("#{root}=") { |v| instance_variable_set("@#{root}", v && File.expand_path(v)) }
    end

    def next_id_path
      File.join(tracker_root, '.next-id')
    end

    def backlog_path
      File.join(tracker_root, 'backlog.md')
    end

    # Every root this project is allowed to touch. Nils are dropped rather than
    # expanded - an unset root must never widen a scope check into a wildcard
    # (BT-136).
    def roots
      [tracker_root, docs_root, decisions_root].compact.reject(&:empty?).map { |r| File.expand_path(r) }.uniq
    end

    def decisions_next_id_path
      File.join(decisions_root, '.next-id')
    end

    # The ordered list of records in decisions/proposed/ - the decision todo
    # list, named for its membership rule rather than borrowing "backlog",
    # which vocabulary.md reserves for a story stage (BT-ADR-0014).
    def proposed_path
      File.join(decisions_root, 'proposed.md')
    end
  end

  def self.configure
    @config ||= Configuration.new
    yield @config if block_given?
    @config
  end

  def self.config
    @config || configure
  end

  # Filesystem-safe slug from a human title - the single source shared by
  # Core (story filenames) and Dashboard (project slugs) so the two can never
  # drift apart.
  def self.slugify(title)
    title.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
  end

  class Core
    attr_reader :config

    # A markdown checklist line: "- [ ] task" / "* [x] task". Groups: prefix,
    # state, suffix - so a toggle can swap the state without touching the rest.
    # The client never re-derives which lines are subtasks: parse_story_file
    # emits subtask_lines (body-line addresses) and the board renders/toggles
    # by those, so this regex plus subtask_line_indices is the single source.
    SUBTASK = /\A(\s*[-*] \[)([ xX])(\] )/

    def initialize(config)
      @config = config
    end

    # Serializes read-modify-write mutations (story files, backlog.md) across
    # threads and processes. flock is not re-entrant, so nested Core calls
    # (toggle_subtask → update_story) skip re-acquisition via a thread-local.
    def with_lock(&block) = with_lock_on(@config.tracker_root, &block)

    # Decisions carry their own lock file in their own root - the two record
    # kinds may live in different repositories (BT-ADR-0016), so one mutex
    # cannot serve both.
    def with_decisions_lock(&block) = with_lock_on(@config.decisions_root, &block)

    def with_lock_on(root)
      held = (Thread.current[:bacon_tracker_locks] ||= {})
      return yield if held[root]

      FileUtils.mkdir_p(root)
      File.open(File.join(root, '.lock'), File::RDWR | File::CREAT) do |f|
        f.flock(File::LOCK_EX)
        held[root] = true
        begin
          yield
        ensure
          held.delete(root)
        end
      end
    end

    # All story reads go through here - CRLF files are normalized to LF so
    # the \n-anchored frontmatter handling works everywhere.
    def read_story(path)
      # `scrub` replaces invalid byte sequences so a non-UTF-8 / corrupted file
      # can't raise out of parse_story_file and 500 every caller of all_stories
      # (BT-096). Strip a leading UTF-8 BOM so it can't defeat the
      # `start_with?("---\n")` / `# key:` frontmatter checks (BT-095), then
      # normalize CRLF to LF.
      File.read(path, encoding: 'utf-8').scrub.delete_prefix("\uFEFF").gsub("\r\n", "\n")
    end

    # Glob metacharacters that must be backslash-escaped when a literal string
    # (a tracker_root, a namespace, an id) is spliced into a Dir.glob pattern.
    GLOB_META = /[*?\[\]{}\\]/

    # A '.feature' comment-frontmatter header line ('# key: value'). The single
    # source used by every place that delimits the leading header block from the
    # Gherkin body (parse_story_file, set_field_in, locked_update_story).
    FEATURE_HEADER = /^# \w+:/

    # Escape glob metacharacters in a literal so it matches itself verbatim.
    def escape_glob(str)
      str.gsub(GLOB_META) { |c| "\\#{c}" }
    end

    # Dir.glob with the base directory escaped - a tracker_root containing
    # glob metacharacters ([, ], {, }, *, ?) must not change what matches.
    def safe_glob(dir, pattern)
      Dir.glob(File.join(escape_glob(dir), pattern))
    end

    def next_id_value
      path = @config.next_id_path
      id = File.exist?(path) ? File.read(path, encoding: 'utf-8').strip.to_i : 0
      id.zero? ? 1 : id
    end

    def consume_id
      consume_counter(@config.next_id_path) { max_story_id }
    end

    # Issue the next id from a locked counter file. The floor is what makes this
    # safe rather than the lock alone: a corrupted or stale counter (merge
    # conflict, hand edit, stale checkout) must never reissue a live id, so it is
    # raised above the highest id already on disk on every read.
    #
    # The floor is record-shaped and therefore a block: stories count story
    # files, decisions count decision files, and neither may floor against the
    # other's corpus (BT-154).
    def consume_counter(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, File::RDWR | File::CREAT) do |f|
        f.flock(File::LOCK_EX)
        id    = f.read.strip.to_i
        floor = yield.to_i + 1
        id    = floor if id < floor
        f.rewind
        f.write((id + 1).to_s)
        f.truncate(f.pos)
        id
      end
    end

    def format_id(n)
      format("#{@config.namespace.gsub('%', '%%')}-%03d", n)
    end

    # Decision ids are a separate sequence in the same namespace, four digits
    # wide, carrying the ADR token that keeps them distinct from story ids
    # (BT-ADR-0014).
    def consume_decision_id
      consume_counter(@config.decisions_next_id_path) { max_decision_number }
    end

    def format_decision_id(n)
      format("#{@config.namespace.gsub('%', '%%')}-ADR-%04d", n)
    end

    def max_decision_number
      decisions.map { |r| r[:number] }.max.to_i
    end

    # The story-ID pattern for this namespace - the single source for every
    # ID match. Unanchored: use filename_id_pattern for filename starts.
    def id_pattern
      @id_pattern ||= /#{Regexp.escape(@config.namespace)}-\d+/
    end

    def filename_id_pattern
      @filename_id_pattern ||= /\A#{id_pattern}/
    end

    def slugify(title)
      BaconTracker.slugify(title)
    end

    # A non-empty slug for a filename. slugify keeps only [a-z0-9], so a title
    # with no ASCII alphanumerics (all-CJK, all-punctuation) slugs to "" - fall
    # back to 'untitled' so the file is "<id>-untitled.ext", not a dangling
    # "<id>-.ext" with a blank humanized name (BT-095). The real title stays in
    # the file's Title:/Feature: line.
    def filename_slug(title)
      slug = slugify(title)
      slug.empty? ? 'untitled' : slug
    end

    def story_dirs
      STORY_DIRS.flat_map do |dir, meta|
        STAGES.map do |stage|
          path = File.join(@config.tracker_root, dir, stage)
          { path: path, type: meta[:type], ext: meta[:ext], stage: stage, dir: dir }
        end
      end.select { |d| Dir.exist?(d[:path]) }
    end

    def find_story(id)
      # Only a well-formed story id may address a file - an id containing '/'
      # or '..' would otherwise let find_story (and its mutating callers:
      # delete/set_stage/update/toggle) reach outside the tracker via the glob
      # (BT-097). id_pattern is namespace-anchored NS-<digits>.
      return nil unless id.to_s.match?(/\A#{id_pattern}\z/)

      glob_safe_id = escape_glob(id)
      story_dirs.each do |d|
        matches = safe_glob(d[:path], "#{glob_safe_id}-*")
        return d.merge(file: matches.first) if matches.any?
      end
      nil
    end

    # One `git log` pass mapping every tracked file (relative to tracker_root) to
    # its first-commit timestamp - story:migrate used to spawn git per file.
    # `--relative` makes the paths tracker_root-relative (git otherwise prints
    # repo-root-relative paths, which never matched when tracker_root is a subdir
    # of the repo - the tracker-init layout - silently falling back to mtime
    # ordering, BT-105).
    def git_first_commit_times
      out = `git -C #{Shellwords.shellescape(@config.tracker_root)} log --diff-filter=A --format=%x00%at --name-only --relative 2>/dev/null`
      map = {}
      ts  = nil
      out.each_line(chomp: true) do |line|
        if line.start_with?("\u0000")
          ts = line.delete_prefix("\u0000").to_i
        elsif !line.empty? && ts
          map[line] = ts # log is newest-first, so the oldest add wins by overwriting
        end
      end
      map
    end

    def already_migrated?(file)
      File.basename(file).match?(filename_id_pattern)
    end

    def frontmatter_md(id, type, status)
      "---\nid: #{id}\ntype: #{type}\nstatus: #{status}\n---\n\n"
    end

    def frontmatter_feature(id, type, status)
      "# id: #{id}\n# type: #{type}\n# status: #{status}\n\n"
    end

    def backlog_ids
      return [] unless File.exist?(@config.backlog_path)

      File.readlines(@config.backlog_path, encoding: 'utf-8').filter_map { |line| backlog_line_id(line) }
    end

    # Entry lines only, by the same rule as backlog_ids - a heading that merely
    # mentions an id ("# Backlog (see NS-099)") is not the next task (BT-179).
    def backlog_lines
      return [] unless File.exist?(@config.backlog_path)

      File.readlines(@config.backlog_path, encoding: 'utf-8').select { |l| backlog_line_id(l) }
    end

    def backlog_story_files
      STORY_DIRS.keys.flat_map do |dir|
        safe_glob(File.join(@config.tracker_root, dir, '2_backlog'), "#{escape_glob(@config.namespace)}-*.{md,feature}")
      end
    end

    def humanize_slug(filename)
      base = File.basename(filename, File.extname(filename))
      base.sub(/\A#{id_pattern}-/, '').gsub('-', ' ')
    end

    # Delegates to set_frontmatter_field: the substitution stays scoped to the
    # frontmatter block (a body line like "status: healthy" is never touched)
    # and a missing status field is added instead of silently skipped.
    def update_frontmatter_status(path, new_status)
      set_frontmatter_field(path, 'status', new_status)
    end

    # A title or frontmatter value must stay on its own line - a newline would
    # inject extra frontmatter keys or backlog.md entries.
    def assert_safe_title!(title)
      raise ArgumentError, 'title must be a string without newlines' if !title.is_a?(String) || title.include?("\n")
    end

    def set_frontmatter_field(path, field, value)
      atomic_write(path, set_field_in(read_story(path), File.extname(path), field, value, File.basename(path)))
    end

    # Pure content transform behind set_frontmatter_field - update_story folds
    # several field edits into one in-memory content and writes once.
    def set_field_in(content, ext, field, value, label)
      raise ArgumentError, "#{field} value must not contain newlines" if value.to_s.include?("\n")

      # An empty value means "remove the field", not "set it to blank" - without
      # this, "" is truthy and would write a dangling "field: " line (BT-095).
      value = nil if value == ''

      # A leading '---' block is YAML frontmatter regardless of extension, so it
      # must be edited as YAML - even for a '.feature' file authored that way,
      # matching parse_story_file's precedence (BT-120).
      if content.start_with?("---\n")
        pattern = /^#{Regexp.escape(field)}: .*\n/
        parts = content.split(/^---\n/, 3)
        raise ArgumentError, "malformed frontmatter in #{label}" unless parts.size == 3

        if value
          enc = yaml_scalar(value)
          new_fm = parts[1].match?(pattern) ? parts[1].sub(pattern) { "#{field}: #{enc}\n" } \
                                            : "#{parts[1]}#{field}: #{enc}\n"
          "---\n#{new_fm}---\n#{parts[2]}"
        else
          "---\n#{parts[1].gsub(pattern, '')}---\n#{parts[2]}"
        end
      elsif ext == '.feature'
        pattern = /^# #{Regexp.escape(field)}: .*\n/
        # Scope the edit to the leading '# key: value' header block only - a
        # body comment further down (e.g. '# size: TBD' in a scenario) must not
        # be matched or rewritten (BT-099). header_end is the first non-header line.
        lines      = content.lines
        header_end = lines.index { |l| !l.match?(FEATURE_HEADER) } || lines.size
        header     = lines[0...header_end]
        rest       = lines[header_end..] || []
        header =
          if value
            new_line = "# #{field}: #{value}\n"
            if header.any? { |l| l.match?(pattern) }
              header.map { |l| l.match?(pattern) ? new_line : l }
            else
              header + [new_line]
            end
          else
            header.reject { |l| l.match?(pattern) }
          end
        (header + rest).join
      else
        raise ArgumentError, "#{label} has no recognizable frontmatter"
      end
    end

    # Encode a value as a single-line YAML scalar so field values containing
    # ':' , '#', or other YAML indicators round-trip instead of producing an
    # unparseable frontmatter block - which Psych would reject on the next read,
    # silently dropping every field of the story (BT-098). Only for YAML
    # frontmatter ('.md', or a '.feature' authored with '---'); the '.feature'
    # gherkin-comment format is parsed by our own 'split(": ", 2)' and must stay
    # unquoted (its branch never calls this). Newlines are already rejected
    # upstream; line_width: -1 stops Psych folding a long plain scalar (a dozen
    # blocked_by ids) onto an indented continuation line that the next
    # `^field: .*\n` edit would orphan (BT-179).
    def yaml_scalar(value)
      value.to_s.to_yaml(line_width: -1).sub(/\A---\s*/, '').chomp
    end

    # Write via a sibling temp file + rename so a concurrent lock-free reader
    # (all_stories/backlog_lines run outside the write lock) always sees a
    # complete file, never the truncated middle of an in-place File.write, and
    # a failed write leaves the original untouched (BT-079). rename(2) is atomic
    # within a filesystem, and the temp lives in the same dir to stay on it.
    def atomic_write(path, content)
      tmp = File.join(File.dirname(path), ".#{File.basename(path)}.tmp.#{Process.pid}")
      File.write(tmp, content)
      File.rename(tmp, path)
    rescue StandardError
      File.delete(tmp) if tmp && File.exist?(tmp)
      raise
    end

    # Normalize a T-shirt size to S/M/L (upcased), treating nil/"" as "unset"
    # and raising on anything else - the one rule shared by create_story and
    # update_story so the two entry points can't disagree (BT-101).
    def normalized_size!(size)
      return nil if size.nil?
      raise ArgumentError, 'size must be a string' unless size.is_a?(String)
      return nil if size.empty?

      up = size.upcase
      raise ArgumentError, 'size must be S, M, or L' unless %w[S M L].include?(up)

      up
    end

    def move_to_stage(result, new_stage)
      old_path = result[:file]
      new_dir  = File.join(@config.tracker_root, result[:dir], new_stage)
      FileUtils.mkdir_p(new_dir)
      new_path = File.join(new_dir, File.basename(old_path))
      if File.exist?(new_path)
        raise ArgumentError,
              "#{File.basename(old_path)} already exists in #{new_stage} - refusing to overwrite (duplicate ID? run story:lint)."
      end
      FileUtils.mv(old_path, new_path)
      new_path
    end

    def backlog_add(id, filename)
      title    = humanize_slug(filename)
      existing = File.exist?(@config.backlog_path) ? File.read(@config.backlog_path, encoding: 'utf-8') : ''
      # Normalize the trailing newline first so a hand-edited backlog.md that
      # doesn't end in one doesn't glue the new entry onto the last line
      # (BT-103). Read + atomic_write also spares a lock-free reader a torn append.
      existing += "\n" unless existing.empty? || existing.end_with?("\n")
      atomic_write(@config.backlog_path, "#{existing}- #{id} #{title}\n")
    end

    def backlog_remove(id)
      return unless File.exist?(@config.backlog_path)

      lines = File.readlines(@config.backlog_path, encoding: 'utf-8')
      atomic_write(@config.backlog_path, lines.reject { |l| backlog_line_id(l) == id }.join)
    end

    # backlog.md membership derives from 2_backlog/ - drop story lines whose
    # file is gone (phantom) and append lines for stories lacking one
    # (unlisted, at the bottom). Runs inside mutation paths, under the lock,
    # so external edits converge instead of drifting until someone lints.
    def heal_backlog!
      on_disk = backlog_story_files.to_h { |f| [File.basename(f)[filename_id_pattern], f] }
      on_disk.delete(nil)
      lines = File.exist?(@config.backlog_path) ? File.readlines(@config.backlog_path, encoding: 'utf-8') : []
      kept  = lines.select { |l| (id = backlog_line_id(l)).nil? || on_disk.key?(id) }
      listed    = kept.filter_map { |l| backlog_line_id(l) }
      additions = (on_disk.keys - listed).map { |id| "- #{id} #{humanize_slug(on_disk[id])}\n" }
      atomic_write(@config.backlog_path, (kept + additions).join) if kept != lines || additions.any?
    end

    # proposed.md's counterpart of heal_backlog!: membership is derived from
    # decisions/proposed/, the order is the human's, and non-entry lines (the
    # heading, blanks, comments) are preserved. Same contract, different record
    # shape - the two share the rule, not the code path, because the id pattern
    # and the title source differ (BT-154).
    def heal_proposed!
      path = @config.proposed_path
      return unless @config.decisions_root && Dir.exist?(@config.decisions_root)

      on_disk = decisions.select { |r| r[:stage] == 'proposed' }.to_h { |r| [r[:id], r] }
      lines   = File.exist?(path) ? File.readlines(path, encoding: 'utf-8') : []
      pattern = /\A\s*-\s+(#{Regexp.escape(@config.namespace)}-ADR-\d{4})/

      kept   = lines.select { |l| (id = l[pattern, 1]).nil? || on_disk.key?(id) }
      listed = kept.filter_map { |l| l[pattern, 1] }
      adds   = (on_disk.keys - listed).map do |id|
        "- #{id} - #{decision_title(on_disk[id])}\n"
      end
      atomic_write(path, (kept + adds).join) if kept != lines || adds.any?
    end

    # The '# heading' is the title; BT-ADR-0014 keeps no title key precisely so
    # the two cannot drift.
    def decision_title(record)
      record[:body][/^#\s+(.+)$/, 1] || record[:filename]
    end

    # Stories whose frontmatter status disagrees with their stage directory
    # (the directory is authoritative). Surfaced by rake story:lint.
    def status_drift
      all_stories.filter_map do |s|
        declared = s[:declared_status]
        actual   = STATUS_MAP[s[:stage]]
        next if declared.nil? || declared == actual

        { id: s[:id], declared: declared, actual: actual, path: s[:path] }
      end
    end

    # Relationship findings whose kind is a flow signal rather than corruption -
    # reported by story:lint, but never on their own a reason to exit non-zero.
    RELATIONSHIP_WARNINGS = %i[started_while_blocked].freeze

    # Findings over the blocked_by/linked_to graph (BT-121). Surfaced by
    # rake story:lint, which decides which kinds fail a build.
    #
    # Two deliberate exemptions keep this actionable instead of merely loud:
    #
    # Only tokens shaped like a story ID for THIS namespace are treated as
    # references. `blocked_by` legitimately names things outside the tracker -
    # BT-024 waits on `sinatra-5.x` - and calling those dangling would punish a
    # real use of the field. An ID from another namespace reads as external for
    # the same reason: this tracker cannot resolve it either way.
    #
    # Stories in 4_done are never the SUBJECT of a finding. Done is append-only
    # (see docs/flow.md), so their relationships are historical record, not an
    # actionable state - and reporting them would make lint noisier with every
    # story that ships. Done stories still count as the OBJECT of a reference:
    # that is exactly what #stale_blocker detects.
    def relationship_findings
      stories = all_stories
      by_id   = stories.to_h { |s| [s[:id], s] }
      live    = stories.reject { |s| s[:stage] == '4_done' }
      exact   = /\A#{id_pattern}\z/

      findings = live.sort_by { |s| s[:id] }.flat_map do |s|
        blocker_findings(s, by_id, exact) + dangling_links(s, by_id, exact)
      end

      findings + blocker_cycles(live, by_id)
    end

    # A story's blocked_by entries, classified. Order matters: a missing
    # blocker can't also be done, and a done blocker makes "started while
    # blocked" moot - the story isn't really blocked, its frontmatter is stale.
    def blocker_findings(story, by_id, exact)
      story[:blocked_by].select { |r| r.match?(exact) }.filter_map do |bid|
        blocker = by_id[bid]
        kind =
          if blocker.nil?                   then :dangling
          elsif blocker[:stage] == '4_done' then :stale_blocker
          elsif story[:stage] == '3_started' then :started_while_blocked
          end
        next unless kind

        { kind: kind, id: story[:id], ref: bid, field: 'blocked_by',
          ref_stage: blocker && blocker[:stage], path: story[:path] }
      end
    end

    def dangling_links(story, by_id, exact)
      story[:linked_to].select { |r| r.match?(exact) }.reject { |lid| by_id.key?(lid) }.map do |lid|
        { kind: :dangling, id: story[:id], ref: lid, field: 'linked_to',
          ref_stage: nil, path: story[:path] }
      end
    end

    # Cycles in the blocked_by graph - A waits on B waits on A, or a story that
    # names itself. Nothing can ever start, so this is a deadlock the tracker
    # should refuse to keep quiet about. Each cycle is rotated to begin at its
    # lowest ID, so reaching the same cycle from two entry points reports once.
    def blocker_cycles(live, by_id)
      graph = live.to_h { |s| [s[:id], s[:blocked_by].select { |b| by_id.key?(b) }] }
      state = {}
      path  = []
      found = {}

      visit = lambda do |id|
        return if state[id] == :done

        if state[id] == :visiting
          cycle = path[path.index(id)..]
          found[cycle.rotate(cycle.index(cycle.min))] = true
          return
        end

        state[id] = :visiting
        path.push(id)
        graph[id].each { |bid| visit.call(bid) if graph.key?(bid) }
        path.pop
        state[id] = :done
      end

      graph.each_key { |id| visit.call(id) }
      found.keys.sort.map { |c| { kind: :cycle, id: c.first, cycle: c, path: by_id[c.first][:path] } }
    end

    # The story ID of a backlog ENTRY line ("- NS-123 title"). Anchored to the
    # entry format so an ID merely mentioned in a comment/heading/prose line
    # ("<!-- NS-123 archived -->") is not treated as a backlog member - which
    # made story:lint report false phantoms (BT-107). Returns nil for non-entry
    # lines. (Filenames use filename_id_pattern, not this.)
    def backlog_line_id(line)
      m = line.match(/\A\s*-\s+(#{id_pattern})/)
      m && m[1]
    end

    # ── Decisions (BT-ADR-0014) ───────────────────────────────────────────────
    # A record is <NS>-ADR-NNNN-slug.md inside a status directory. The directory
    # is the source of truth for status; frontmatter mirrors it (0006's rule,
    # applied to decisions). Everything else in decisions_root is not a record.

    def decision_record_pattern
      @decision_record_pattern ||=
        /\A#{Regexp.escape(@config.namespace)}-ADR-(\d{4})-.+\.md\z/
    end

    # Every .md in a status directory, whether or not it is a valid record -
    # the invalid ones are what the "not-a-record" warning is for.
    def decision_files
      root = @config.decisions_root
      return [] unless root && Dir.exist?(root)

      STATUSES.flat_map do |status|
        safe_glob(File.join(root, status), '*.md').map { |p| [status, p] }
      end
    end

    def decisions
      decision_files.filter_map do |status, path|
        name = File.basename(path)
        m = name.match(decision_record_pattern)
        next unless m

        fm, body = parse_decision_file(path)
        {
          id:           "#{@config.namespace}-ADR-#{m[1]}",
          number:       m[1].to_i,
          stage:        status,
          declared:     fm['status']&.to_s,
          date:         fm['date'].to_s,
          fm:           fm,
          body:         body,
          path:         path,
          filename:     name,
          frontmatter?: File.read(path, encoding: 'utf-8').start_with?("---\n")
        }
      end
    end

    # The board's read shape (BT-144): one entry per record, frontmatter
    # lifted, title from the # heading (BT-ADR-0014 keeps no title key so the
    # two cannot drift), docs_path present when the record is reachable
    # through the docs surface for the editor/reveal actions.
    def decisions_board
      docs_base = @config.docs_root && File.expand_path(@config.docs_root)
      order = proposed_order
      sorted = decisions.sort_by do |r|
        # Proposed records follow proposed.md - position is the priority
        # (BT-147); every other status reads by id.
        r[:stage] == 'proposed' ? [0, order.index(r[:id]) || order.size, r[:number]] : [1, r[:number], 0]
      end
      sorted.map do |r|
        expanded = File.expand_path(r[:path])
        {
          id:            r[:id],
          status:        r[:stage],
          title:         r[:body][/^#\s+(.+)$/, 1] || r[:filename],
          date:          r[:date],
          supersedes:    decision_refs(r[:fm]['supersedes']),
          superseded_by: decision_refs(r[:fm]['superseded_by']),
          stories:       decision_refs(r[:fm]['stories']),
          canonical:     r[:fm]['canonical'].to_s.then { |c| c.empty? ? nil : c },
          docs_path:     if docs_base && expanded.start_with?(docs_base + File::SEPARATOR)
                           expanded.delete_prefix(docs_base + File::SEPARATOR)
                         end
        }
      end
    end

    # Lint findings over the decision corpus. Severity follows 0013: integrity
    # fails the build, hygiene reports and exits clean. Ids outside this
    # project's namespace are never resolved - this checkout cannot settle them
    # either way, so it must not claim they are broken.
    def decision_findings
      root = @config.decisions_root
      return [] unless root && Dir.exist?(root)

      records = decisions
      out     = []
      f = ->(kind, id, msg, path) { out << { kind: kind, severity: :failure, id: id, message: msg, path: path } }
      w = ->(kind, id, msg, path) { out << { kind: kind, severity: :warning, id: id, message: msg, path: path } }

      decision_files.each do |_status, path|
        name = File.basename(path)
        next if name.match?(decision_record_pattern)

        w.call('not-a-record', nil,
               "#{name} is not a record filename (<NS>-ADR-NNNN-slug.md) - a forgotten id?", path)
      end

      by_number = records.group_by { |r| r[:number] }
      by_number.each do |num, group|
        next if group.size < 2

        f.call('duplicate-id', format('%s-ADR-%04d', @config.namespace, num),
               "id used by #{group.size} records: #{group.map { |r| r[:filename] }.join(', ')}",
               group.first[:path])
      end

      ids = records.map { |r| r[:id] }.to_set

      records.each do |r|
        # A record with no frontmatter yields one finding and suppresses the
        # per-key checks (BT-ADR-0014 amendment) - three findings for one cause
        # is noise, and BT-130's acceptance count assumes this.
        unless r[:frontmatter?]
          f.call('no-frontmatter', r[:id], 'no YAML frontmatter block', r[:path])
          next
        end

        if r[:declared].nil? || r[:declared].empty?
          f.call('missing-status', r[:id], 'frontmatter has no status', r[:path])
        elsif !STATUSES.include?(r[:declared])
          f.call('unknown-status', r[:id], "status #{r[:declared].inspect} is not one of #{STATUSES.join(', ')}", r[:path])
        elsif r[:declared] != r[:stage]
          f.call('status-drift', r[:id],
                 "status says #{r[:declared]} but the record is in #{r[:stage]}/ - the directory is authoritative", r[:path])
        end

        if r[:date].empty?
          f.call('missing-date', r[:id], 'frontmatter has no date', r[:path])
        elsif !r[:date].match?(/\A\d{4}-\d{2}-\d{2}\z/)
          f.call('bad-date', r[:id], "date #{r[:date].inspect} is not ISO-8601 (YYYY-MM-DD)", r[:path])
        end

        %w[supersedes superseded_by].each do |field|
          decision_refs(r[:fm][field]).each do |ref|
            next unless ref.start_with?("#{@config.namespace}-ADR-")
            next f.call('dangling-ref', r[:id], "#{field} names #{ref}, which does not exist", r[:path]) unless ids.include?(ref)

            other = records.find { |x| x[:id] == ref }
            mirror = field == 'supersedes' ? 'superseded_by' : 'supersedes'
            unless decision_refs(other[:fm][mirror]).include?(r[:id])
              f.call('asymmetric-supersession', r[:id],
                     "#{field} names #{ref}, but #{ref} does not name it back in #{mirror}", r[:path])
            end
          end
        end

        if r[:stage] == 'superseded' && decision_refs(r[:fm]['superseded_by']).empty?
          w.call('no-successor', r[:id], 'superseded with an empty superseded_by', r[:path])
        end

        canonical = r[:fm]['canonical'].to_s
        if canonical.start_with?("#{@config.namespace}-ADR-")
          w.call('own-canonical', r[:id],
                 'canonical points inside this project - an adoption should defer to another project', r[:path])
        end

        prose = r[:body][/^##\s+Status\s*\n+(\S+)/, 1]
        if prose && prose.downcase.delete('^a-z') != r[:stage]
          w.call('prose-drift', r[:id],
                 "the ## Status prose says #{prose.inspect} but the record is in #{r[:stage]}/", r[:path])
        end
      end

      out.concat(proposed_findings(records))

      max = records.map { |r| r[:number] }.max
      if max
        nxt = File.exist?(@config.decisions_next_id_path) ? File.read(@config.decisions_next_id_path).strip.to_i : 0
        if nxt <= max
          f.call('stale-next-id', nil,
                 "#{'.next-id'} is #{nxt}, at or below the highest id on disk (#{max})",
                 @config.decisions_next_id_path)
        end
      end

      out
    end

    # Decisions parse their own frontmatter: parse_story_file requires a story-id
    # filename match, which an <NS>-ADR-NNNN name never satisfies.
    def parse_decision_file(path)
      content = File.read(path, encoding: 'utf-8')
      return [{}, content] unless content.start_with?("---\n")

      parts = content.split(/^---\n/, 3)
      fm = begin
        YAML.safe_load(parts[1].to_s, permitted_classes: [Date, Time])
      rescue Psych::Exception => e
        warn "[BaconTracker] ignoring malformed frontmatter in #{File.basename(path)}: #{e.message}"
        nil
      end
      fm = {} unless fm.is_a?(Hash)
      [fm.transform_keys(&:to_s), parts[2].to_s.lstrip]
    end

    # A frontmatter list value, tolerating the scalar and comma-separated forms
    # the field grammar already accepts elsewhere (0009) and a hand-authored
    # YAML list (`blocked_by: [A, B]`). Shared by stories and decisions.
    def decision_refs(value)
      case value
      when Array then value.map { |v| v.to_s.strip }.reject(&:empty?)
      when nil   then []
      else value.to_s.split(/\s*,\s*/).map(&:strip).reject(&:empty?)
      end
    end

    def proposed_findings(records)
      path = @config.proposed_path
      listed = if File.exist?(path)
                 File.readlines(path, encoding: 'utf-8').filter_map do |line|
                   line[/\A\s*-\s+(#{Regexp.escape(@config.namespace)}-ADR-\d{4})/, 1]
                 end
               else
                 []
               end
      in_proposed = records.select { |r| r[:stage] == 'proposed' }.map { |r| r[:id] }

      (listed - records.map { |r| r[:id] }).map do |ghost|
        { kind: 'phantom-entry', severity: :failure, id: ghost,
          message: "proposed.md lists #{ghost}, which does not exist", path: path }
      end +
        (listed & records.map { |r| r[:id] } - in_proposed).map do |moved|
          { kind: 'listed-not-proposed', severity: :failure, id: moved,
            message: "proposed.md lists #{moved}, which is no longer in proposed/", path: path }
        end +
        (in_proposed - listed).map do |missing|
          { kind: 'unlisted', severity: :failure, id: missing,
            message: "#{missing} is in proposed/ but missing from proposed.md", path: path }
        end
    end

    # Extensions a docs page can have. Markdown only is the product decision;
    # txt rides along as the one plain form worth rendering (§13.2).
    DOC_EXTENSIONS = %w[.md .markdown .txt].freeze

    # A file is a page if it renders in the docs browser: right extension, not
    # a dotfile, not `_`-hidden, and not part of a tracked subtree - decision
    # records are counted as decisions, and a tracker tree living inside the
    # docs tree is work, not documentation (BT-ADR-0016).
    def docs_pages
      root = @config.docs_root
      return [] unless root && Dir.exist?(root)

      # The tracker tree is excluded only when it sits INSIDE the docs tree -
      # BT-ADR-0016's derived exclusion. The other direction (a docs folder
      # under a broad tracker_root) must not erase the docs tree.
      expanded  = File.expand_path(root)
      tracker   = @config.tracker_root && File.expand_path(@config.tracker_root)
      skip_roots = [@config.decisions_root && File.expand_path(@config.decisions_root),
                    (tracker if tracker&.start_with?(expanded + File::SEPARATOR))]
                   .compact.map { |r| r + File::SEPARATOR }

      Dir.glob(File.join(escape_glob(root), '**', '*'))
         .select { |f| File.file?(f) && DOC_EXTENSIONS.include?(File.extname(f).downcase) }
         .reject { |f| File.basename(f).start_with?('.', '_') }
         .reject { |f| skip_roots.any? { |sr| File.expand_path(f).start_with?(sr) } }
    end

    # Recently changed pages (BT-151), from git history rather than mtime - a
    # checkout touches every file's mtime without any of them having changed.
    # One log pass newest-first; the first time a path appears is its latest
    # change. No repository (or git absent) is an empty list, never an error.
    RECENT_LIMIT = 20

    def docs_recent
      root = @config.docs_root
      return [] unless root && Dir.exist?(root)

      out = `git -C #{Shellwords.shellescape(root)} log --format=%x00%at --name-only --relative 2>/dev/null`
      return [] if out.empty?

      visible = visible_docs_set
      seen = {}
      at = nil
      out.each_line(chomp: true) do |line|
        if line.start_with?("\x00")
          at = line.delete_prefix("\x00").to_i
        elsif !line.empty? && !seen.key?(line) && visible.include?(line)
          seen[line] = at
          break if seen.size >= RECENT_LIMIT
        end
      end
      seen.map { |path, ts| { path: path, at: ts, date: Time.at(ts).strftime('%Y-%m-%d') } }
    end

    # What links here (BT-152): every visible page whose relative markdown
    # links resolve to the target, plus - when the target is a decision record
    # - every page citing its id. A grep, which is the thing a filesystem tool
    # can do that Confluence never could.
    def docs_backlinks(target_rel)
      root = @config.docs_root
      return [] unless root && Dir.exist?(root)

      base = File.expand_path(root)
      target = File.expand_path(target_rel, base).delete_prefix(base + File::SEPARATOR)
      target_id = File.basename(target)[/\A([A-Z][A-Z0-9]*-ADR-\d{4})/, 1]

      all_docs_files.filter_map do |file|
        rel = File.expand_path(file).delete_prefix(base + File::SEPARATOR)
        next if rel == target

        content = File.read(file, encoding: 'utf-8')
        linked = content.scan(/\]\(([^)#\s]+)\)/).flatten.any? do |href|
          next false if href.match?(%r{\A[a-z]+:|\A/})

          File.expand_path(href, File.dirname(File.join(base, rel)))
              .delete_prefix(base + File::SEPARATOR) == target
        end
        cited = target_id && content.include?(target_id)
        { path: rel } if linked || cited
      rescue ArgumentError
        nil
      end
    end

    def all_docs_files
      docs_pages + (@config.decisions_root ? decisions.map { |r| r[:path] } : [])
    end

    def visible_docs_set
      base = File.expand_path(@config.docs_root)
      all_docs_files.map { |f| File.expand_path(f).delete_prefix(base + File::SEPARATOR) }.to_set
    end

    # Full-text search over the docs surface (BT-150): the pages the tree
    # lists plus the decision records - never hidden files, since docs_pages
    # and decisions already carry the visibility rules. Pure Ruby by choice:
    # the corpora are dozens of files, so no shell-out and no dependency; the
    # scan is trivially swappable if a corpus ever outgrows it.
    SEARCH_PER_FILE = 3
    SEARCH_TOTAL    = 100

    def docs_search(query)
      q = query.to_s.strip.downcase
      return [] if q.empty?

      docs_base = File.expand_path(@config.docs_root.to_s)
      files = docs_pages +
              (@config.decisions_root ? decisions.map { |r| r[:path] } : [])
      hits = []
      files.each do |file|
        break if hits.size >= SEARCH_TOTAL

        rel = File.expand_path(file).delete_prefix(docs_base + File::SEPARATOR)
        per = 0
        File.foreach(file, encoding: 'utf-8').with_index(1) do |line, no|
          next unless line.downcase.include?(q)

          hits << { path: rel, folder: File.dirname(rel), lineno: no, line: line.strip[0, 200] }
          per += 1
          break if per >= SEARCH_PER_FILE || hits.size >= SEARCH_TOTAL
        end
      rescue ArgumentError
        next # undecodable bytes in one file must not kill the search
      end
      hits
    end

    # The identity files at the project root (BT-149). Fixed basenames only -
    # no caller-supplied path ever reaches this, so there is nothing to scope.
    # Every key is optional and nil when absent, per the missing-file posture.
    def project_front
      root = @config.project_root
      return {} unless root && Dir.exist?(root)

      readme    = File.join(root, 'README.md')
      changelog = File.join(root, 'CHANGELOG.md')
      version, ambiguous = resolve_version(root)
      {
        readme_html:       (render_markdown(File.read(readme, encoding: 'utf-8')) if File.file?(readme)),
        changelog_html:    (render_markdown(File.read(changelog, encoding: 'utf-8')) if File.file?(changelog)),
        version:           version,
        version_ambiguous: ambiguous
      }
    end

    def render_markdown(text)
      doc = Kramdown::Document.new(gfm_table_compat(text), input: 'GFM', hard_wrap: false)
      sanitize_tree!(doc.root)
      doc.to_html
    end

    # Rendered markdown lands in a page that can call the write API, so it is
    # sanitised before it leaves the server (BT-179): kramdown passes raw HTML
    # through verbatim, and a `<img onerror>` or `[x](javascript:)` in a
    # teammate's page would run on the board's origin. kramdown has no
    # sanitiser of its own; this walks its element tree instead. Raw HTML
    # elements and {::nomarkdown} spans are dropped whole - markdown is the
    # product decision (BT-ADR-0018), and an allowlist would be a second one.
    UNSAFE_ELEMENT_TYPES = %i[html_element xml_pi xml_comment raw].freeze
    URL_ATTRIBUTES       = %w[href src].freeze
    SAFE_URL_SCHEMES     = %w[http https mailto].freeze
    CHECKBOX_ATTRIBUTES  = %w[class checked].freeze

    def sanitize_tree!(el)
      el.children.reject! { |c| UNSAFE_ELEMENT_TYPES.include?(c.type) && !task_checkbox!(c) }
      # IAL syntax ({: onclick="..."}) can plant any attribute on any element.
      el.attr.delete_if { |k, _| k.start_with?('on') || k == 'style' }
      URL_ATTRIBUTES.each { |a| el.attr.delete(a) if el.attr.key?(a) && !safe_url?(el.attr[a]) }
      el.children.each { |c| sanitize_tree!(c) }
      el
    end

    # The GFM parser renders "- [ ]" as an html_element input - the one raw
    # element the docs surface needs. Keep it, rebuilt as an inert, disabled
    # checkbox with nothing an author could have added (true = keep).
    def task_checkbox!(el)
      return false unless el.type == :html_element && el.value == 'input' && el.attr['type'] == 'checkbox'

      el.attr.keep_if { |k, _| CHECKBOX_ATTRIBUTES.include?(k) }
      el.attr['type']     = 'checkbox'
      el.attr['disabled'] = 'disabled'
      el.children.clear
      true
    end

    # Relative, anchor and absolute-path URLs have no scheme and pass; a
    # scheme must be one of the three. Control characters are stripped first
    # because browsers ignore them inside a scheme ("java\tscript:").
    def safe_url?(url)
      scheme = url.to_s.gsub(/[\x00-\x20]/, '')[/\A([a-z][a-z0-9+.-]*):/i, 1]
      scheme.nil? || SAFE_URL_SCHEMES.include?(scheme.downcase)
    end

    # kramdown's GFM parser demands a blank line before a table; GitHub's does
    # not, and the corpus is written against GitHub's (five of drop's eight
    # README tables sit flush under a heading - GitHub-legal, kramdown-
    # invisible). Insert the blank line kramdown wants, fence-aware so pipe
    # art inside code blocks is never touched (BT-173).
    def gfm_table_compat(text)
      lines  = text.lines
      out    = []
      fence  = nil
      lines.each_with_index do |line, i|
        if (m = line.match(/\A(`{3,}|~{3,})/))
          fence = fence.nil? ? m[1][0] * 3 : nil
        elsif fence.nil? &&
              line.match?(/\A\s*\|/) &&
              lines[i + 1]&.match?(/\A\s*\|?[ :|-]*-[ :|-]*\|?\s*\z/) &&
              out.last && !out.last.strip.empty? && !out.last.match?(/\A\s*\|/)
          out << "\n"
        end
        out << line
      end
      out.join
    end

    # VERSION discovery (BT-162, settled): an explicit version_path overrides
    # everything; otherwise ./VERSION, then */VERSION one level deep. Two
    # candidates and no override is an ambiguity to report, never a guess.
    def resolve_version(root)
      if @config.version_path
        path = File.expand_path(@config.version_path, root)
        return [File.file?(path) ? File.read(path).strip : nil, nil]
      end

      direct = File.join(root, 'VERSION')
      return [File.read(direct).strip, nil] if File.file?(direct)

      candidates = safe_glob(root, '*/VERSION').select { |f| File.file?(f) }.sort
      case candidates.size
      when 0 then [nil, nil]
      when 1 then [File.read(candidates.first).strip, nil]
      else [nil, candidates.map { |f| f.delete_prefix(File.expand_path(root) + File::SEPARATOR) }]
      end
    end

    # The docs tree as nested nodes for the column browser. Same visibility
    # rules as docs_pages, plus: a tracked subtree shows its records but never
    # its machinery (proposed.md, .next-id, _template.md), and a directory with
    # nothing renderable in it is not a column entry at all.
    def docs_tree(dir = nil)
      root = @config.docs_root
      return [] unless root && Dir.exist?(root)

      dir ||= File.expand_path(root)
      tracker = @config.tracker_root && File.expand_path(@config.tracker_root)

      Dir.children(dir).sort.filter_map do |name|
        next if name.start_with?('.', '_')

        full = File.join(dir, name)
        # docs_pages' glob does not follow symlinked directories; the tree must
        # not list what the page read would then refuse (BT-179).
        next if File.symlink?(full) && File.directory?(full)

        if File.directory?(full)
          next if tracker && File.expand_path(full) == tracker &&
                  tracker.start_with?(File.expand_path(@config.docs_root) + File::SEPARATOR)

          children = docs_tree(full)
          next if children.empty?

          node = { name: name, type: 'dir', path: relative_docs_path(full), children: children }
          # The decisions directory is a tracked subtree with its own board -
          # the browser sends it there instead of column-walking it (BT-176).
          node[:decisions] = true if @config.decisions_root &&
                                     File.expand_path(full) == File.expand_path(@config.decisions_root)
          node
        else
          next unless DOC_EXTENSIONS.include?(File.extname(name).downcase)
          next if in_decisions?(full) && name == 'proposed.md'

          { name: name, type: 'page', path: relative_docs_path(full) }
        end
      end
    end

    # Read one page by its docs-relative path. The scope check is the point:
    # this is a web-reachable file read (BT-159), so anything the tree would
    # not list - traversal, absolute paths, hidden files, non-page extensions -
    # raises without ever touching the file.
    def docs_page(rel)
      File.read(docs_file!(rel), encoding: 'utf-8')
    end

    # The one scope check for every docs-relative path a client can hand us -
    # page reads, editor opens, reveals. Anything the tree would not list
    # raises before the filesystem is touched (BT-159). allow_dir admits a
    # folder for reveal (BT-143); pages stay files with page extensions.
    def docs_file!(rel, allow_dir: false)
      root = @config.docs_root
      raise ArgumentError, 'no docs root configured' unless root && Dir.exist?(root)

      expanded = File.expand_path(rel.to_s, root)
      base     = File.expand_path(root)
      unless expanded.start_with?(base + File::SEPARATOR)
        raise ArgumentError, 'path is outside the docs root'
      end

      parts = expanded.delete_prefix(base + File::SEPARATOR).split(File::SEPARATOR)
      if parts.any? { |p| p.start_with?('.', '_') }
        raise ArgumentError, 'hidden files are not pages'
      end
      if File.basename(expanded) == 'proposed.md' && in_decisions?(expanded)
        raise ArgumentError, 'proposed.md is rendered by the board, not the browser'
      end

      # Only a tracker tree INSIDE the docs tree is excluded - the reverse
      # containment (a broad tracker root holding docs/) must not blank the
      # docs surface. Same direction rule as docs_pages.
      tracker = @config.tracker_root && File.expand_path(@config.tracker_root)
      if tracker && tracker.start_with?(base + File::SEPARATOR) &&
         expanded.start_with?(tracker + File::SEPARATOR)
        raise ArgumentError, 'the tracker tree is not documentation'
      end

      return within_docs!(expanded, base) if allow_dir && File.directory?(expanded)

      unless DOC_EXTENSIONS.include?(File.extname(expanded).downcase)
        raise ArgumentError, 'not a renderable page'
      end
      raise ArgumentError, 'page not found' unless File.file?(expanded)

      within_docs!(expanded, base)
    end

    # The lexical check above is on the path as given; this one is on where it
    # really points, so a symlink inside docs/ cannot read outside it (BT-179).
    # The root is resolved too: /tmp is itself a link on macOS.
    def within_docs!(path, base)
      real_base = File.realpath(base)
      raise ArgumentError, 'path is outside the docs root' unless File.realpath(path).start_with?(real_base + File::SEPARATOR)

      path
    rescue Errno::ENOENT, Errno::ELOOP
      raise ArgumentError, 'page not found'
    end

    # A page plus its rendered HTML. Markdown goes through kramdown's GFM
    # input (BT-ADR-0018) - task lists and tables are what the corpus actually
    # uses; txt is escaped verbatim, parsed as nothing.
    def render_page(rel)
      content = docs_page(rel)
      # Frontmatter is fields, never rendered YAML (BT-141) - any page may
      # carry a block, decision records always do.
      fm, body =
        if content.start_with?("---\n")
          parts = content.split(/^---\n/, 3)
          parsed = begin
            YAML.safe_load(parts[1].to_s, permitted_classes: [Date, Time])
          rescue Psych::Exception
            nil
          end
          # Stringify values too - YAML parses dates into Date objects, and the
          # JSON the client receives should carry the literal the file does.
          parsed.is_a?(Hash) ? [parsed.to_h { |k, v| [k.to_s, v.is_a?(Array) ? v.map(&:to_s) : v.to_s] }, parts[2].to_s.lstrip] : [{}, content]
        else
          [{}, content]
        end
      html =
        if File.extname(rel).downcase == '.txt'
          "<pre>#{body.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')}</pre>"
        else
          render_markdown(body)
        end
      title = body[/^#\s+(.+)$/, 1] || File.basename(rel)
      { path: rel, title: title, content: content, frontmatter: fm, html: html }
    end

    def relative_docs_path(full)
      File.expand_path(full).delete_prefix(File.expand_path(@config.docs_root) + File::SEPARATOR)
    end

    def in_decisions?(path)
      d = @config.decisions_root
      d && File.expand_path(path).start_with?(File.expand_path(d) + File::SEPARATOR)
    end

    def docs_stats
      records = @config.decisions_root ? decisions : []
      {
        pages:     docs_pages.size,
        decisions: records.size,
        proposed:  records.count { |r| r[:stage] == 'proposed' }
      }
    end

    # Create a proposed record from _template.md (BT-146): id from the locked
    # counter, filename per the contract, today's date and the title stamped
    # over the template's placeholders so the record is lint-clean from birth.
    # Web-reachable - raises, never aborts (BT-ADR-0005).
    def create_decision(title)
      title = title.to_s.strip
      raise ArgumentError, 'a decision needs a title' if title.empty?

      root = @config.decisions_root
      raise ArgumentError, 'no decisions root configured' unless root

      with_decisions_lock do
        heal_proposed!
        id   = format_decision_id(consume_decision_id)
        slug = filename_slug(title) # never "<id>-.md", which is not a record
        template_path = File.join(root, '_template.md')
        body = File.exist?(template_path) ? File.read(template_path, encoding: 'utf-8') : Templates::DECISION
        today = Date.today.iso8601
        # Block form: a title containing \0 or \& must land verbatim, not as a
        # backreference (BT-179).
        body = body.gsub(/^date: .*$/, "date: #{today}")
                   .gsub(/^- Date: .*$/, "- Date: #{today}")
                   .sub(/^# .*$/) { "# #{title}" }

        FileUtils.mkdir_p(File.join(root, 'proposed'))
        path = File.join(root, 'proposed', "#{id}-#{slug}.md")
        atomic_write(path, body)
        heal_proposed!
        path
      end
    end

    # Allowed decision transitions (BT-ADR-0017), keyed by destination. Forward
    # only: nothing returns to proposed - reversing a decision means superseding
    # it with a new record - and rejected/deprecated/superseded are terminal.
    DECISION_TRANSITIONS = {
      'accepted'   => %w[proposed],
      'rejected'   => %w[proposed],
      'deprecated' => %w[accepted],
      'superseded' => %w[accepted]
    }.freeze

    # The one transition primitive. Every surface - board, API, Rake, command -
    # funnels here, so none of them can disagree about what a decision means.
    # Web-reachable: raises ArgumentError, never aborts (BT-ADR-0005).
    #
    # Returns { id:, status:, external: } - :external lists a superseding id in
    # another namespace whose reciprocal side was NOT written, because this
    # checkout cannot edit another repository (BT-ADR-0013's rule applied to
    # writes). The caller is told rather than the other half being pretended.
    def set_status(id, new_status, superseded_by: nil)
      unless STATUSES.include?(new_status)
        raise ArgumentError, "Invalid status: #{new_status} (one of: #{STATUSES.join(', ')})"
      end
      if new_status == 'proposed'
        raise ArgumentError, 'nothing returns to proposed - supersede with a new record instead.'
      end

      with_decisions_lock do
        heal_proposed!
        record = decisions.find { |r| r[:id] == id }
        raise ArgumentError, "Decision #{id} not found." unless record
        next { id: id, status: new_status, external: [] } if record[:stage] == new_status
        # A record without a frontmatter block cannot carry a status - lint
        # already flags it; a transition is a 400, not a NoMethodError (BT-179).
        raise ArgumentError, "#{id} has no frontmatter block - fix the record before transitioning it." unless record[:frontmatter?]

        unless DECISION_TRANSITIONS[new_status].include?(record[:stage])
          raise ArgumentError,
                "#{id} is #{record[:stage]} - #{record[:stage]} → #{new_status} is not a " \
                'transition. An accepted record changes by amendment or supersession; a ' \
                'terminal one is history.'
        end

        # Validate everything before writing anything: a missing or dangling
        # target must leave both records untouched, never a bare status write
        # (BT-ADR-0017).
        target   = nil
        external = []
        if new_status == 'superseded'
          ref = superseded_by.to_s.strip
          raise ArgumentError, 'superseded_by is required: name the decision that supersedes this one.' if ref.empty?

          if ref.start_with?("#{@config.namespace}-ADR-")
            target = decisions.find { |r| r[:id] == ref }
            raise ArgumentError, "superseded_by names #{ref}, which does not exist here." unless target
          else
            external << ref
          end
        end

        # The destination directory may not exist yet (a project scaffolded
        # before decisions existed, or only proposed/ created on first use) -
        # make it before any write, so a failed mv can't strand a rewritten
        # record in its old directory with the new status (BT-179).
        dest_dir = File.join(@config.decisions_root, new_status)
        FileUtils.mkdir_p(dest_dir)

        moves_date = %w[accepted rejected].include?(new_status)
        rewrite_decision(record,
                         status: new_status,
                         date:   moves_date ? Date.today.iso8601 : nil,
                         append: new_status == 'superseded' ? ['superseded_by', superseded_by.to_s.strip] : nil)
        rewrite_decision(target, append: ['supersedes', id]) if target

        FileUtils.mv(record[:path], File.join(dest_dir, record[:filename]))
        heal_proposed!
        { id: id, status: new_status, external: external }
      end
    end

    def proposed_order
      path = @config.proposed_path
      return [] unless @config.decisions_root && File.exist?(path)

      File.readlines(path, encoding: 'utf-8').filter_map do |l|
        l[/\A\s*-\s+(#{Regexp.escape(@config.namespace)}-ADR-\d{4})/, 1]
      end
    end

    # backlog_reorder's semantics on proposed.md (BT-147): non-entry lines
    # keep their place, the client's order applies to the entries it knew
    # about, and entries it did not know about survive at the bottom rather
    # than being silently deleted.
    def proposed_reorder(ordered_ids)
      raise ArgumentError, "'ids' must be an array" unless ordered_ids.is_a?(Array)

      with_decisions_lock do
        heal_proposed!
        path = @config.proposed_path
        next unless File.exist?(path)

        pattern = /\A\s*-\s+(#{Regexp.escape(@config.namespace)}-ADR-\d{4})/
        lines = File.readlines(path, encoding: 'utf-8')
        id_to_line = lines.each_with_object({}) { |l, h| (m = l[pattern, 1]) && h[m] = l }
        non_entry  = lines.reject { |l| l[pattern, 1] }
        ordered    = ordered_ids.uniq.filter_map { |id| id_to_line[id] }
        leftover   = lines.select { |l| (m = l[pattern, 1]) && !ordered_ids.include?(m) }
        atomic_write(path, (non_entry + ordered + leftover).join)
      end
    end

    # Surgical frontmatter/prose edit for a transition. Line-level, never a YAML
    # round-trip - a reserialize would reformat 17 records\' worth of hand-written
    # frontmatter to make one edit.
    def rewrite_decision(record, status: nil, date: nil, append: nil)
      content = File.read(record[:path], encoding: 'utf-8')
      parts   = content.split(/^---\n/, 3)
      fm, body = parts[1], parts[2]

      # Block-form substitutions throughout: a value is data, never a
      # backreference pattern (BT-179).
      fm = fm.sub(/^status:.*$/) { "status: #{status}" } if status
      if date
        fm = fm.match?(/^date:/) ? fm.sub(/^date:.*$/) { "date: #{date}" } : fm + "date: #{date}\n"
      end
      if append
        key, value = append
        fm = if (m = fm.match(/^#{Regexp.escape(key)}:\s*\[(.*)\]\s*$/))
               existing = m[1].strip
               list = existing.empty? ? value : "#{existing}, #{value}"
               fm.sub(/^#{Regexp.escape(key)}:.*$/) { "#{key}: [#{list}]" }
             else
               fm + "#{key}: [#{value}]\n"
             end
      end
      # Keep the prose mirror in step so a tool-driven transition never plants a
      # prose-drift warning; a hand edit remains the lint\'s problem.
      body = body.sub(/^(##\s+Status\s*\n+)\S+/) { "#{$1}#{status.capitalize}" } if status

      atomic_write(record[:path], "---\n#{fm}---\n#{body}")
    end

    # CLI adapter for decision transitions - the abort side of the 0005
    # boundary, exactly as commit/start/done wrap set_stage.
    def transition_decision(id, new_status, superseded_by: nil)
      result = set_status(id, new_status, superseded_by: superseded_by)
      msg = "#{result[:id]} → #{result[:status]}/"
      unless result[:external].empty?
        msg += " (#{result[:external].join(', ')} is in another namespace - its supersedes side was NOT written; record it there)"
      end
      puts msg
    rescue ArgumentError => e
      abort e.message
    end

    # ── Rake-facing wrappers ──────────────────────────────────────────────────
    # Thin CLI adapters over the raising primitives: Core itself never aborts;
    # only these wrappers convert ArgumentError into a clean process exit.

    # Commit to a story: icebox → backlog. The name is deliberate - moving a
    # story into the backlog is the act of commitment, not the start of work
    # (that's #start). See docs/flow.md.
    def commit(id)
      with_lock do
        result = find_story(id)
        abort "Story #{id} not found." unless result
        abort "#{id} is in #{result[:stage]}, expected 1_icebox." unless result[:stage] == '1_icebox'

        set_stage(id, '2_backlog')
        puts "Committed #{id} → 2_backlog/#{File.basename(result[:file])}, added to backlog.md"
      end
    rescue ArgumentError => e
      abort e.message
    end

    # Start work on a story: backlog → started. Pull from the top of the
    # backlog - the prioritization already happened at commit time.
    def start(id)
      with_lock do
        result = find_story(id)
        abort "Story #{id} not found." unless result
        abort "#{id} is in #{result[:stage]}, expected 2_backlog." unless result[:stage] == '2_backlog'

        set_stage(id, '3_started')
        puts "Started #{id} → 3_started/#{File.basename(result[:file])}"
      end
    rescue ArgumentError => e
      abort e.message
    end

    def done(id)
      with_lock do
        result = find_story(id)
        abort "Story #{id} not found." unless result
        abort "#{id} is already done." if result[:stage] == '4_done'

        set_stage(id, '4_done')
        backlog_remove(id) # set_stage only removes from 2_backlog; drop strays too
        puts "Done #{id} → 4_done/#{File.basename(result[:file])}"
      end
    rescue ArgumentError => e
      abort e.message
    end

    # Create a story, optionally setting fields in one step. `fields` is a hash
    # of #update_story keyword args (size/assignee/blocked_by/linked_to/body/title) - the
    # same set the `story:edit` task parses. A field-validation failure is
    # reported against the just-created story so its ID isn't lost.
    def create(kind, title, fields = {})
      story = create_story(kind, title)
      path  =
        if fields.empty?
          story[:path]
        else
          begin
            update_story(story[:id], **fields)
          rescue ArgumentError => e
            abort "Created #{story[:id]} but could not set fields: #{e.message}"
          end
        end
      puts "#{story[:id]}: #{path}"
    rescue ArgumentError => e
      abort e.message
    end

    # Fields #update_story (and the `story:edit` task / `/tracker edit`) can set.
    EDITABLE_FIELDS = %w[title body size assignee blocked_by linked_to].freeze

    # Editable fields whose value is a comma-separated list of story IDs (rather
    # than a plain scalar) - the single source for edit_assignments' list-splitting
    # and locked_update_story's array coercion, so a new relationship field is
    # added in one place.
    ID_LIST_FIELDS = %w[blocked_by linked_to].freeze

    # Parse rake-style "field=value" tokens into #update_story keyword args.
    # Rake comma-splits bracket args, so a comma-separated value like
    # `blocked_by=A,B` arrives as ["blocked_by=A", "B"]; a token with `=` starts
    # a field, a bare token continues the previous field's list. An empty value
    # (`size=`) is kept as "" so the field is removed. Raises on unknown fields.
    def edit_assignments(tokens)
      fields  = {}
      current = nil
      tokens.each do |tok|
        key = tok.split('=', 2).first.to_s.strip
        # A token opens a new field only if its key is an editable field name.
        # A '=' inside a value (e.g. "title=Compare a=1, b=2", which rake splits
        # on the comma) is thus kept as a continuation, and a bare stray token
        # ("size" instead of "size=S") raises instead of being silently dropped
        # (BT-106).
        if tok.include?('=') && EDITABLE_FIELDS.include?(key)
          current = key
          fields[current] = tok.split('=', 2)[1]
        elsif current
          fields[current] += ",#{tok}"
        elsif tok.include?('=')
          raise ArgumentError, "Unknown field(s): #{key}. Editable: #{EDITABLE_FIELDS.join(', ')}"
        else
          raise ArgumentError, "Expected field=value (one of #{EDITABLE_FIELDS.join(', ')}), got: #{tok.strip.inspect}"
        end
      end

      fields.each_with_object({}) do |(key, val), kwargs|
        kwargs[key.to_sym] =
          ID_LIST_FIELDS.include?(key) ? val.split(',').map(&:strip).reject(&:empty?) : val
      end
    end

    def parse_story_file(path, dir_meta)
      content = read_story(path)
      ext     = File.extname(path)
      id      = File.basename(path)[filename_id_pattern]
      return nil unless id

      fm, body =
        # A leading '---' block is YAML frontmatter regardless of extension: some
        # projects author '.feature' files with YAML frontmatter rather than the
        # '# key: value' gherkin-comment header, and both must yield the same
        # fields (BT-120 - otherwise linked_to/size/assignee silently vanish).
        if content.start_with?("---\n")
          parts = content.split(/^---\n/, 3)
          # One bad frontmatter block must not take down every caller of
          # all_stories - treat it as empty and keep the story visible.
          fm_hash = begin
            YAML.safe_load(parts[1].to_s, permitted_classes: [Date, Time])
          rescue Psych::Exception => e
            warn "[BaconTracker] ignoring malformed frontmatter in #{File.basename(path)}: #{e.message}"
            nil
          end
          fm_hash = {} unless fm_hash.is_a?(Hash)
          [fm_hash.transform_keys(&:to_s), parts[2].to_s.lstrip]
        elsif ext == '.feature'
          lines = content.lines.take_while { |l| l.match?(FEATURE_HEADER) }
          # A header line without a ': ' separator (e.g. '# type:bug') splits to
          # a single element - tolerate it instead of letting .to_h raise and
          # 500 every caller of all_stories, matching the YAML branch's
          # resilience above (BT-078; the YAML side was hardened in BT-055).
          fm_hash = lines.each_with_object({}) do |l, h|
            key, val = l.sub(/^# /, '').chomp.split(': ', 2)
            h[key] = val unless val.nil?
          end
          rest = content.lines.drop(lines.size).join.lstrip
          [fm_hash, rest]
        else
          [{}, content]
        end

      raw_size = fm['size']&.to_s&.upcase
      size = %w[S M L].include?(raw_size) ? raw_size : nil

      blocked_by = decision_refs(fm['blocked_by'])
      linked_to  = decision_refs(fm['linked_to'])

      assignee = fm['assignee']&.to_s&.strip
      assignee = nil if assignee&.empty?

      st_lines = subtask_line_indices(body.lines, ext)
      subtasks = subtask_counts(body, ext)

      { id: id, type: dir_meta[:type], stage: dir_meta[:stage], dir: dir_meta[:dir],
        path: path, title: humanize_slug(path), body: body, size: size,
        blocked_by: blocked_by, linked_to: linked_to, assignee: assignee, subtasks: subtasks,
        # Body-line addresses of the subtasks - the client renders/toggles by
        # these instead of re-deriving fence rules (the BT-049 drift class).
        subtask_lines: st_lines.empty? ? nil : st_lines,
        declared_status: fm['status']&.to_s }
    end

    # Indices of body lines that are subtasks, skipping fenced content
    # (``` code blocks in markdown, """ docstrings in gherkin) to stay
    # consistent with what the board renders as clickable.
    def subtask_line_indices(lines, ext)
      fence = ext == '.feature' ? '"""' : '```'
      in_fence = false
      lines.each_index.select do |i|
        if lines[i].lstrip.start_with?(fence)
          in_fence = !in_fence
          next false
        end
        !in_fence && lines[i].match?(SUBTASK)
      end
    end

    def subtask_counts(body, ext)
      lines  = body.to_s.lines
      states = subtask_line_indices(lines, ext).map { |i| lines[i][SUBTASK, 2] }
      return nil if states.empty?

      { done: states.count { |s| s.casecmp?('x') }, total: states.size }
    end

    def toggle_subtask(id, index, done)
      raise ArgumentError, "'index' must be a non-negative integer" unless index.is_a?(Integer) && index >= 0
      raise ArgumentError, "'done' must be true or false" unless [true, false].include?(done)

      with_lock do
        result = find_story(id)
        raise ArgumentError, "Story #{id} not found." unless result

        ext    = File.extname(result[:file])
        # find_story's glob ("<id>-*") is looser than parse_story_file's id
        # contract, so a hand-created odd filename can match yet parse to nil -
        # raise ArgumentError (→ 400) instead of a NoMethodError → 500 (BT-080).
        parsed = parse_story_file(result[:file], result)
        raise ArgumentError, "Story #{id} not found." unless parsed

        lines = parsed[:body].lines
        pos   = subtask_line_indices(lines, ext)[index]
        raise ArgumentError, "Story #{id} has no subtask at index #{index}." unless pos

        lines[pos] = lines[pos].sub(SUBTASK) { "#{$1}#{done ? 'x' : ' '}#{$3}" }
        update_story(id, body: lines.join)
        subtask_counts(lines.join, ext)
      end
    end

    def all_stories
      story_dirs.flat_map do |d|
        safe_glob(d[:path], '*.{md,feature}').filter_map do |f|
          next if File.basename(f).start_with?('_')

          parse_story_file(f, d)
        end
      end
    end

    # Annotate each story with its derived reverse relationships: `blocks` (the
    # inverse of `blocked_by`) and `linked_from` (the inverse of `linked_to`).
    # A file-based tracker can't transactionally write the far side of a pair, so
    # a relationship lives on exactly one story's frontmatter and the other end is
    # computed here over the whole set - the board renders both ends without any
    # second-file write. `linked_to`/`linked_from` describe the same symmetric
    # link from each side; the UI unions them into one 🔗 badge.
    def with_reverse_links(stories)
      blocks      = Hash.new { |h, k| h[k] = [] }
      linked_from = Hash.new { |h, k| h[k] = [] }
      stories.each do |s|
        s[:blocked_by].each { |bid| blocks[bid]      << s[:id] }
        s[:linked_to].each  { |lid| linked_from[lid] << s[:id] }
      end
      stories.map { |s| s.merge(blocks: blocks[s[:id]], linked_from: linked_from[s[:id]]) }
    end

    def stats
      # Counting is glob-only - the menu app polls this every few seconds and
      # stage lives in the directory name, so no file needs to be read/parsed.
      esc_ns = escape_glob(@config.namespace)
      counts = Hash.new(0)
      story_dirs.each { |d| counts[d[:stage]] += safe_glob(d[:path], "#{esc_ns}-[0-9]*.{md,feature}").size }

      done_n    = counts['4_done']
      started_n = counts['3_started']
      backlog_n = counts['2_backlog']
      icebox_n  = counts['1_icebox']
      total     = done_n + started_n + backlog_n + icebox_n
      pct       = total.zero? ? 0 : (done_n * 100.0 / total).round

      next_line = backlog_lines.first&.strip
      next_task = next_line&.sub(/^-\s+#{id_pattern}\s+/, '')

      { done: done_n, started: started_n, backlog: backlog_n, icebox: icebox_n,
        total: total, progress_pct: pct, next_task: next_task }
    end

    def duplicate_id_stages
      id_to_paths = Hash.new { |h, k| h[k] = [] }
      story_dirs.each do |d|
        safe_glob(d[:path], '*.{md,feature}').each do |f|
          next if File.basename(f).start_with?('_')

          id = File.basename(f)[filename_id_pattern]
          id_to_paths[id] << f if id
        end
      end
      id_to_paths.select { |_, paths| paths.size > 1 }
    end

    def max_story_id
      story_dirs.flat_map do |d|
        safe_glob(d[:path], '*.{md,feature}').filter_map do |f|
          File.basename(f)[/\A#{Regexp.escape(@config.namespace)}-(\d+)/, 1]&.to_i
        end
      end.max || 0
    end

    def set_stage(id, new_stage)
      raise ArgumentError, "Invalid stage: #{new_stage}" unless STAGES.include?(new_stage)

      with_lock do
        heal_backlog!
        result = find_story(id)
        raise ArgumentError, "Story #{id} not found." unless result
        next STATUS_MAP[result[:stage]] if result[:stage] == new_stage
        # 4_done is append-only (docs/flow.md): a done story is never reopened -
        # file a new story instead. Guards the board's drag-out-of-done (BT-102).
        if result[:stage] == '4_done'
          raise ArgumentError, "#{id} is done - done is append-only; file a new story instead of reopening it."
        end

        old_stage = result[:stage]
        old_path  = result[:file]
        # Validate before moving: the status rewrite raises on malformed
        # frontmatter, and doing it after the mv left the file in the new stage
        # with a 400 reported and backlog.md untouched (BT-179).
        content   = set_field_in(read_story(old_path), File.extname(old_path), 'status',
                                 STATUS_MAP[new_stage], File.basename(old_path))
        new_path  = move_to_stage(result, new_stage)
        atomic_write(new_path, content)

        backlog_remove(id) if old_stage == '2_backlog'
        backlog_add(id, new_path) if new_stage == '2_backlog'

        STATUS_MAP[new_stage]
      end
    end

    def backlog_reorder(ordered_ids)
      raise ArgumentError, "'ids' must be an array" unless ordered_ids.is_a?(Array)

      with_lock do
        heal_backlog!
        next unless File.exist?(@config.backlog_path)

        lines = File.readlines(@config.backlog_path, encoding: 'utf-8')
        id_to_line = lines.each_with_object({}) do |l, h|
          (m = backlog_line_id(l)) && h[m] = l
        end
        non_story = lines.reject { |l| backlog_line_id(l) }
        ordered   = ordered_ids.uniq.filter_map { |id| id_to_line[id] }
        # A stale client's order may not know about lines added since it
        # loaded - keep them (at the bottom) instead of silently deleting.
        leftover  = lines.select { |l| (m = backlog_line_id(l)) && !ordered_ids.include?(m) }
        atomic_write(@config.backlog_path, (non_story + ordered + leftover).join)
      end
    end

    def create_story(kind, title, stage: '1_icebox', size: nil)
      assert_safe_title!(title)
      # Validate size the same way update_story does, before an ID is consumed -
      # create used to silently drop an invalid size while update raised (BT-101).
      norm_size = normalized_size!(size)
      meta = STORY_DIRS.find { |_, m| m[:type] == kind }
      raise ArgumentError, "Unknown kind: #{kind}" unless meta
      raise ArgumentError, "Unknown stage: #{stage}" unless STAGES.include?(stage)

      dir, m = meta
      ext    = m[:ext]

      with_lock do
        id_num = consume_id
        id     = format_id(id_num)
        slug   = filename_slug(title)

        filename = "#{id}-#{slug}#{ext}"
        dest_dir = File.join(@config.tracker_root, dir, stage)
        FileUtils.mkdir_p(dest_dir)
        dest   = File.join(dest_dir, filename)
        status = STATUS_MAP[stage]

        template_path = File.join(@config.tracker_root, dir, "_template#{ext}")
        template = if File.exist?(template_path)
                     File.read(template_path, encoding: 'utf-8')
                   else
                     Templates.for(ext, kind)
                   end
        filled = if ext == '.feature'
                   template.sub('Name the Feature') { title }
                 else
                   template.sub(/\ATitle:.*/) { "Title: #{title}" }
                 end
        fm      = kind == 'feature' ? frontmatter_feature(id, kind, status) : frontmatter_md(id, kind, status)
        content = fm + filled

        atomic_write(dest, content)
        backlog_add(id, dest) if stage == '2_backlog'
        set_frontmatter_field(dest, 'size', norm_size) if norm_size

        parse_story_file(dest, { type: kind, stage: stage, dir: dir })
      end
    end

    def delete_story(id)
      with_lock do
        result = find_story(id)
        raise ArgumentError, "Story #{id} not found." unless result
        # Done is a permanent record (docs/flow.md / README) - refuse to delete
        # it from any front-end, not just the /tracker prose path (BT-081).
        if result[:stage] == '4_done'
          raise ArgumentError, "#{id} is done - done stories are a permanent record and are not deleted."
        end

        backlog_remove(id) if result[:stage] == '2_backlog'
        File.delete(result[:file])
        true
      end
    end

    def update_story(id, title: nil, body: nil, size: nil, blocked_by: nil, linked_to: nil, assignee: nil)
      assert_safe_title!(title) if title
      with_lock { locked_update_story(id, title, body, size, blocked_by, linked_to, assignee) }
    end

    # The body of update_story, run under the write lock.
    def locked_update_story(id, title, body, size, blocked_by, linked_to, assignee)
      result = find_story(id)
      raise ArgumentError, "Story #{id} not found." unless result

      path    = result[:file]
      ext     = File.extname(path)
      content = read_story(path)

      if [size, blocked_by, linked_to, assignee].any? { |v| !v.nil? } &&
         ext != '.feature' && !content.start_with?("---\n")
        raise ArgumentError, "#{File.basename(path)} has no recognizable frontmatter"
      end

      if body
        content =
          # A leading '---' block is YAML frontmatter regardless of extension and
          # must be preserved as such, even on a '.feature' authored that way
          # (BT-120) - mirrors parse_story_file / set_field_in precedence.
          if content.start_with?("---\n")
            parts = content.split(/^---\n/, 3)
            # Same guard set_field_in has: refuse a body edit on a file with an
            # opening '---' but no closing one, instead of fusing the body into
            # the frontmatter block (BT-100).
            raise ArgumentError, "#{File.basename(path)} has malformed frontmatter" unless parts.size == 3

            "---\n#{parts[1]}---\n\n#{body.chomp}\n"
          elsif ext == '.feature'
            fm_lines = content.lines.take_while { |l| l.match?(FEATURE_HEADER) }
            fm_lines.join + "\n" + body.chomp + "\n"
          else
            body.chomp + "\n"
          end
      end

      # Title substitution runs after the body rebuild - a combined edit's body
      # still carries the old title line, which would otherwise win.
      if title
        content = if ext == '.feature'
                    content.sub(/^Feature: .+/) { "Feature: #{title}" }
                  else
                    content.sub(/^Title: .+/) { "Title: #{title}" }
                  end
      end

      # Frontmatter edits fold into the in-memory content - every validation
      # runs before the single write, so a failure leaves the file untouched.
      label = File.basename(path)

      unless size.nil?
        content = set_field_in(content, ext, 'size', normalized_size!(size), label)
      end

      unless blocked_by.nil?
        raise ArgumentError, 'blocked_by must be an array' unless blocked_by.is_a?(Array)

        content = set_field_in(content, ext, 'blocked_by', blocked_by.empty? ? nil : blocked_by.join(', '), label)
      end

      unless linked_to.nil?
        raise ArgumentError, 'linked_to must be an array' unless linked_to.is_a?(Array)

        content = set_field_in(content, ext, 'linked_to', linked_to.empty? ? nil : linked_to.join(', '), label)
      end

      unless assignee.nil?
        raise ArgumentError, 'assignee must be a string' unless assignee.is_a?(String)

        content = set_field_in(content, ext, 'assignee', assignee.empty? ? nil : assignee, label)
      end

      if title || body || !size.nil? || !blocked_by.nil? || !linked_to.nil? || !assignee.nil?
        atomic_write(path, content)
        new_path = title ? File.join(File.dirname(path), "#{id}-#{filename_slug(title)}#{ext}") : path
        if path != new_path
          FileUtils.mv(path, new_path)
          path = new_path
          if result[:stage] == '2_backlog' && File.exist?(@config.backlog_path)
            lines = File.readlines(@config.backlog_path, encoding: 'utf-8')
            atomic_write(@config.backlog_path,
                         lines.map { |l| backlog_line_id(l) == id ? "- #{id} #{title}\n" : l }.join)
          end
        end
      end

      path
    end
  end
end
