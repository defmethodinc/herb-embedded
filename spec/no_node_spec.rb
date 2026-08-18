# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"
require "ripper"

NO_NODE_ROOT = File.expand_path("..", __dir__)

# Ruby/RubyGems/Bundler must still resolve; Node must not. Deliberately
# excludes /opt/homebrew/bin (and any Node install's own bin dir), since
# a Homebrew-installed Node symlinks node/npx there too.
NO_NODE_RESTRICTED_PATH = [RbConfig::CONFIG["bindir"], Gem.bindir, "/usr/bin", "/bin"].join(File::PATH_SEPARATOR)

RSpec.describe "No-Node guard" do
  it "lints correctly via herb-lint-rb with no Node reachable on PATH" do
    Dir.mktmpdir do |dir|
      fixture = File.join(dir, "no_node.html.erb")
      File.write(fixture, <<~ERB)
        <div  class="a">
          <img src="logo.png">
        </div>
      ERB

      exe_path = File.join(NO_NODE_ROOT, "exe", "herb-lint-rb")

      stdout, stderr, status = Open3.capture3(
        { "PATH" => NO_NODE_RESTRICTED_PATH }, "bundle", "exec", "ruby", exe_path, fixture, chdir: NO_NODE_ROOT
      )

      expect(stdout).to include("html-img-require-alt")
      expect(status.exitstatus).to eq(1)
      expect(stderr.downcase).not_to match(/\bnode\b|\bnpx\b|enoent/)
    end
  end

  it "never shells out at runtime: no system/exec/spawn/backtick/Open3/IO.popen under lib/**/*.rb" do
    forbidden_idents = %w[system exec spawn popen].freeze
    forbidden_consts = %w[Open3].freeze

    offenders = Dir.glob(File.join(NO_NODE_ROOT, "lib", "**", "*.rb")).each_with_object([]) do |path, found|
      Ripper.lex(File.read(path)).each do |(position, event, token)|
        next unless shell_out_token?(event, token, forbidden_idents, forbidden_consts)

        found << "#{path}:#{position.first}: #{token}"
      end
    end

    expect(offenders).to eq([])
  end

  def shell_out_token?(event, token, forbidden_idents, forbidden_consts)
    return true if event == :on_backtick
    return true if event == :on_ident && forbidden_idents.include?(token)
    return true if event == :on_const && forbidden_consts.include?(token)

    false
  end
end
