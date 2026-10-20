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
         "--main-fields=module,main",
         # postcss (pulled in by the scoped-style and CSS rules in linter
         # 0.11) reaches for Node built-ins it only needs for source maps
         # and terminal colors. Alias those to our no-filesystem stubs;
         # parsing in-memory CSS never takes those paths.
         "--alias:path=./stubs/path.mjs",
         "--alias:fs=./stubs/fs.mjs",
         "--alias:url=./stubs/url.mjs",
         "--alias:util=./stubs/util.mjs",
         "--alias:picocolors=./stubs/picocolors.mjs",
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
