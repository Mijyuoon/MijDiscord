# frozen_string_literal: true

module MijDiscord::Events
  class EventBase
    FilterMatch = Struct.new(:field, :on, :cmp)

    def initialize(*args)
      # Nothing
    end

    def trigger?(params)
      filters = self.class.event_filters

      result = params.map do |key, param|
        next true unless filters.has_key?(key)

        check = filters[key].map do |match|
          on, field, cmp = match.on, match.field, match.cmp

          is_match = case on
            when Array
              on.reduce(false) {|a,x| a || trigger_match?(x, param) }
            else
              trigger_match?(on, param)
          end

          next false unless is_match

          value = case field
            when Array
              field.reduce(self) {|a,x| a.respond_to?(x) ? a.send(x) : nil }
            else
              respond_to?(field) ? send(field) : nil
          end

          case cmp
            when :eql?
              value == param
            when :neq?
              value != param
            when :case
              param === value
            when Proc
              cmp.call(value, param)
            else
              false
          end
        end

        check.reduce(false, &:|)
      end

      result.reduce(true, &:&)
    end

    private

    def trigger_match?(match, key)
      case match
        when :any, :all
          true
        when :id_obj
          key.respond_to?(:to_id)
        when Class
          match === key
      end
    end

    class << self
      attr_reader :event_filters

      def filter_match(key, field: key, on: :any, cmp: nil, &block)
        raise ArgumentError, 'No comparison function provided' unless cmp || block

        # @event_filters ||= superclass&.event_filters&.dup || {}
        filter = (@event_filters[key] ||= [])
        filter << FilterMatch.new(field, on, block || cmp)
      end

      def delegate_method(*names, to:)
        names.each do |name|
          define_method(name) do |*arg|
            send(to).send(name, *arg)
          end
        end
      end

      def inherited(sc)
        filters = @event_filters&.dup || {}
        sc.instance_variable_set(:@event_filters, filters)
      end
    end
  end

  class DispatcherBase
    Callback = Struct.new(:key, :block, :filter)

    def initialize(klass)
      raise ArgumentError, 'Class must inherit from EventBase' unless klass < EventBase

      @klass, @callbacks = klass, {}
    end

    def add_callback(key = nil, **filter, &block)
      raise ArgumentError, 'No callback block provided' if block.nil?

      key = block.object_id if key.nil?
      @callbacks[key] = Callback.new(key, block, filter)
      key
    end

    def remove_callback(key)
      @callbacks.delete(key)
      nil
    end

    def callbacks
      @callbacks.values
    end

    def trigger(event_args, block_args = nil)
      event = @klass.new(*event_args)

      @callbacks.each do |_, cb|
        execute_callback(cb, event, block_args) if event.trigger?(cb.filter)
      end
    end

    alias_method :raise, :trigger

    # Must implement execute_callback
  end
end