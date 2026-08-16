# frozen_string_literal: true

require "fileutils"

namespace :bundle do
  desc "Vendor @herb-tools/linter into vendor/herb-linter.js (requires Node + npm)"
  task :build do
    root = File.expand_path("..", __dir__)
    tmp_outfile = File.join(root, "vendor", "herb-linter.js.tmp")
    outfile = File.join(root, "vendor", "herb-linter.js")

    Dir.chdir(root) do
      sh "npm install"

      sh "npx", "esbuild", "js/entry.mjs",
         "--bundle",
         "--format=iife",
         "--global-name=HerbLinter",
         "--platform=neutral",
         "--alias:@herb-tools/config=./stubs/config.mjs",
         "--outfile=#{tmp_outfile}"

      node_builtin_reference = %r{
        require\(\s*["']node:[a-z/]+["']\s*\)
        |
        require\(\s*["'](fs|path|url|os|crypto|child_process|module|stream|util)["']\s*\)
      }x
      output = File.read(tmp_outfile)

      if output.match?(node_builtin_reference)
        FileUtils.rm_f(tmp_outfile)
        abort "bundle:build aborted: vendor/herb-linter.js would contain a Node built-in reference"
      end

      FileUtils.mv(tmp_outfile, outfile)
      puts "Wrote #{outfile} (#{output.bytesize} bytes)"
    end
  end
end
