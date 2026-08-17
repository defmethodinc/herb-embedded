# frozen_string_literal: true

module Herb
  module Embedded
    # Loads project-local rules from .herb/rules/**/*.mjs. Upstream's own
    # loader uses pathToFileURL, tinyglobby, and dynamic import() — none of
    # which exist in an embedded engine. Ruby replaces the loader entirely:
    # it globs and reads the files, rewrites their one supported import
    # (@herb-tools/linter) into a destructure from the already-loaded
    # bundle, and hands the result to the engine for registration.
    class CustomRuleLoader
      class UnsupportedImportError < StandardError; end
      class InvalidRuleError < StandardError; end

      RULES_GLOB = File.join(".herb", "rules", "**", "*.mjs")
      ALLOWED_SPECIFIER = "@herb-tools/linter"
      IMPORT_LINE = /^import\b.*$/
      NAMED_IMPORT_LINE = /^import\s*\{([^}]*)\}\s*from\s*["']([^"']+)["'];?\s*$/
      EXPORT_DEFAULT_CLASS = /export\s+default\s+class\s+(\w+)/

      def initialize(root:, bridge:)
        @root = root
        @bridge = bridge
      end

      def load_all
        Dir.glob(File.join(@root, RULES_GLOB)).map do |path|
          rewritten = self.class.rewrite(File.read(path), path)
          result = @bridge.register_custom_rule(rewritten, path)

          if result["overrode"]
            warn("Custom rule '#{result["ruleName"]}' at #{path} overrides a built-in rule of the same name")
          end

          result["ruleName"]
        end
      end

      # Only a single supported specifier is rewritten: named imports from
      # "@herb-tools/linter" become a destructure from the bundle-global
      # HerbLinter. Anything else — a different specifier, or an import
      # form other than named braces — fails loudly rather than producing
      # a mysterious ReferenceError at rule-execution time.
      def self.rewrite(source, path)
        named_imports = extract_named_imports(source, path)
        body = strip_import_lines(source)
        body = rewrite_default_export(body, path)
        destructure = named_imports.empty? ? "" : "const { #{named_imports.join(", ")} } = HerbLinter;\n"

        <<~JS
          (function () {
            #{destructure}#{body}
            return __herbCustomRule;
          })()
        JS
      end

      def self.extract_named_imports(source, path)
        named_imports = []

        source.each_line do |line|
          next unless line.match?(IMPORT_LINE)

          match = line.match(NAMED_IMPORT_LINE)
          raise UnsupportedImportError, "#{path}: unsupported import statement: #{line.strip}" unless match

          names, specifier = match.captures
          if specifier != ALLOWED_SPECIFIER
            raise UnsupportedImportError,
                  "#{path}: unsupported import from \"#{specifier}\" (only \"#{ALLOWED_SPECIFIER}\" is supported)"
          end

          named_imports.concat(names.split(",").map(&:strip).reject(&:empty?))
        end

        named_imports
      end
      private_class_method :extract_named_imports

      def self.strip_import_lines(source)
        source.gsub(IMPORT_LINE, "")
      end
      private_class_method :strip_import_lines

      def self.rewrite_default_export(body, path)
        unless body.match?(EXPORT_DEFAULT_CLASS)
          raise InvalidRuleError, "#{path}: no default export found; custom rules must use `export default class`"
        end

        body.sub(EXPORT_DEFAULT_CLASS, 'const __herbCustomRule = class \1')
      end
      private_class_method :rewrite_default_export
    end
  end
end
