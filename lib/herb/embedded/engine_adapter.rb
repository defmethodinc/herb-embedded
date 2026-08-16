# frozen_string_literal: true

module Herb
  module Embedded
    # Port between Ruby and whichever JavaScript engine executes Herb's
    # rule code. Concrete engines (MiniRacer, and later QuickJS/Wasmtime)
    # implement this interface; callers depend only on it.
    class EngineAdapter
      # Marks a Ruby string as binary data that must cross the engine
      # boundary as a byte array (e.g. a Uint8Array), not a JS string,
      # since arbitrary bytes are not valid UTF-8.
      Binary = Struct.new(:raw)

      def self.binary(bytes)
        Binary.new(bytes)
      end

      def load(js)
        raise NotImplementedError, "#{self.class} must implement #load"
      end

      def attach(name, &block)
        raise NotImplementedError, "#{self.class} must implement #attach"
      end

      def call(fn, *args)
        raise NotImplementedError, "#{self.class} must implement #call"
      end

      def dispose
        raise NotImplementedError, "#{self.class} must implement #dispose"
      end
    end
  end
end
