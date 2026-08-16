# frozen_string_literal: true

module Herb
  module Embedded
    # The vendored @herb-tools/linter JS bundle (see rakelib/bundle.rake).
    module Bundle
      LINTER_VERSION = "0.10.3"
      HERB_VERSIONS = ["0.10.3"].freeze

      VENDOR_PATH = File.expand_path("../../../vendor/herb-linter.js", __dir__)

      module_function

      def source
        File.read(VENDOR_PATH)
      end

      def linter_version
        LINTER_VERSION
      end

      def herb_versions
        HERB_VERSIONS
      end
    end
  end
end
