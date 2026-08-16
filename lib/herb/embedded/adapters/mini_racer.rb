# frozen_string_literal: true

require "mini_racer"
require_relative "../engine_adapter"

module Herb
  module Embedded
    module Adapters
      # Reference EngineAdapter backed by mini_racer (bundled V8).
      class MiniRacer < EngineAdapter
        def initialize
          super
          @context = ::MiniRacer::Context.new
        end

        def load(source)
          @context.eval(source)
          self
        end

        def attach(name, &block)
          @context.attach(name, block)
          self
        end

        def call(function, *args)
          converted = args.map { |arg| arg.is_a?(Binary) ? arg.raw.bytes : arg }
          @context.call(function, *converted)
        end

        def dispose
          @context.dispose
        end
      end
    end
  end
end
