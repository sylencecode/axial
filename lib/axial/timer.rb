require 'securerandom'

module Axial
  class TimerError < StandardError
  end

  class Timer
    attr_reader     :uuid, :type, :callback_method
    attr_accessor   :thread, :interval, :last
    attr_writer     :expired, :repeat

    def initialize(repeat, interval, *args, &block)
      set_defaults

      @interval           = (interval < 0.5) ? 0.5 : interval
      @repeat             = repeat
      @args               = *args

      if (block_given?)
        @type             = :block
        @block            = block
        @args             = *args # rubocop:disable Style/IdenticalConditionalBranches
      else
        @type             = :callback
        @callback_object  = args.shift
        @callback_method  = args.shift
        @args             = *args # rubocop:disable Style/IdenticalConditionalBranches
      end
    end

    def set_defaults()
      @uuid               = SecureRandom.uuid
      @last               = Time.now
      @callback_object    = nil
      @callback_method    = nil
      @type               = nil
      @args               = nil
      @block              = nil
      @thread             = nil
      @running            = false
      @expired            = false
    end

    def running?()
      return @running
    end

    def expired?()
      return @expired
    end

    def repeat?()
      return @repeat
    end

    def execute_as_block()
      if (@args.count > 1)
        @block.call(*@args)
      elsif (@args.count == 1)
        @block.call(@args[0])
      else
        @block.call
      end
    end
    private :execute_as_block

    def execute_as_callback()
      if (@args.count > 1)
        @callback_object.public_send(@callback_method.to_sym, *@args)
      elsif (@args.count == 1)
        @callback_object.public_send(@callback_method.to_sym, @args[0])
      else
        @callback_object.public_send(@callback_method.to_sym)
      end
    end
    private :execute_as_callback

    def execute()
      @running = true

      if (@type == :block)
        execute_as_block
      elsif (@type == :callback)
        execute_as_callback
      else
        raise(TimerError, "no idea how to handle response type #{@type}")
      end

      @running = false
    rescue Exception => ex
      @running = false
      LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
      ex.backtrace.each do |i|
        LOGGER.error(i)
      end
    end
  end
end
