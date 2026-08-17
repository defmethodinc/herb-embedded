# frozen_string_literal: true

require_relative "formatters/simple"
require_relative "formatters/detailed"
require_relative "formatters/json"
require_relative "formatters/github"

module Herb
  module Embedded
    # Formatters are pure functions of a Report: #render(report) -> String.
    module Formatters
      REGISTRY = {
        simple: Simple,
        detailed: Detailed,
        json: Json,
        github: Github,
      }.freeze

      module_function

      def fetch(name)
        formatter_class = REGISTRY[name]
        raise ArgumentError, "Unknown formatter: #{name.inspect}" unless formatter_class

        formatter_class.new
      end
    end
  end
end
