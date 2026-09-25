require 'spec_helper'
require 'open3'

# End-to-end coverage for the bin/tracker-dashboard executable's error paths
# (it had none - BT-096). The success path boots a blocking Puma server, so only
# the early exit-1 branches are exercised here.
RSpec.describe 'tracker-dashboard' do
  let(:gem_root) { File.expand_path('..', __dir__) }

  def run_dashboard(*args)
    Open3.capture3(
      RbConfig.ruby, "-I#{gem_root}/lib", File.join(gem_root, 'bin', 'tracker-dashboard'), *args
    )
  end

  it 'exits 1 when dashboard.md does not exist' do
    Dir.mktmpdir do |root|
      _out, err, status = run_dashboard('--dashboard', File.join(root, 'nope.md'))
      expect(status).not_to be_success
      expect(err).to match(/not found/i)
    end
  end

  it 'exits 1 when the dashboard has no projects' do
    Dir.mktmpdir do |root|
      dash = File.join(root, 'dashboard.md')
      File.write(dash, "# Bacon Dashboard\n\n(no projects configured yet)\n")
      _out, err, status = run_dashboard('--dashboard', dash)
      expect(status).not_to be_success
      expect(err).to match(/No projects found/i)
    end
  end
end
