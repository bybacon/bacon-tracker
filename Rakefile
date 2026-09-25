require 'bacon_tracker'
require 'bacon_tracker/tasks'

BaconTracker.configure do |c|
  c.namespace       = 'BT'
  c.tracker_root    = File.expand_path('docs/tracker', __dir__)
  c.docs_root       = File.expand_path('docs', __dir__)
  c.decisions_root  = File.expand_path('docs/decisions', __dir__)
  c.project_root    = __dir__
end

BaconTracker::Tasks.install
BaconTracker::Tasks.install_version_tasks
