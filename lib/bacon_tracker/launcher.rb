require 'rbconfig'
require 'shellwords'

module BaconTracker
  # Opening a file in an editor, or revealing it in the file manager, is the
  # one thing the board does outside its own files - and the only part that
  # differs by platform. Everything else is plain Ruby file I/O.
  #
  # A missing launcher is reported, never swallowed: the endpoints answer 501
  # with the reason, so the board can say so instead of claiming success.
  module Launcher
    class Unavailable < StandardError; end

    module_function

    def host_os = RbConfig::CONFIG['host_os']

    def windows? = host_os.match?(/mswin|mingw|cygwin/)
    def macos?   = host_os.include?('darwin')

    # Show a file (or folder) in the file manager.
    def reveal_argv(target)
      if macos?
        ['open', '-R', target]
      elsif windows?
        ['explorer.exe', "/select,#{target}"]
      elsif which('xdg-open')
        # xdg-open has no "select this file" - open the folder that holds it.
        ['xdg-open', File.directory?(target) ? target : File.dirname(target)]
      end
    end

    # Open a file in the user's editor. BACON_EDITOR wins and may carry
    # arguments ("code -w"); otherwise the platform's default handler.
    def open_argv(target)
      editor = ENV['BACON_EDITOR'].to_s.strip
      return Shellwords.split(editor) + [target] unless editor.empty?

      if macos?
        ['open', target]
      elsif windows?
        ['cmd.exe', '/c', 'start', '', target]
      elsif which('xdg-open')
        ['xdg-open', target]
      end
    end

    # Fire and forget: the board never waits on an editor. No shell is
    # involved - argv goes straight to exec, so a path is never interpreted.
    def run(argv)
      raise Unavailable, 'no launcher found on this system - install xdg-open or set BACON_EDITOR' unless argv

      pid = Process.spawn(*argv, out: File::NULL, err: File::NULL)
      Process.detach(pid)
      nil
    rescue SystemCallError => e
      raise Unavailable, "could not run #{argv.first}: #{e.message}"
    end

    def which(cmd)
      ENV['PATH'].to_s.split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, cmd)) }
    end
  end
end
