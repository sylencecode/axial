require 'securerandom'

module Axial
  class TimerError < StandardError
  end

  class Timer
    attr_reader     :uuid, :type, :callback_method
    attr_accessor   :thread, :interval, :last
    attr_writer     :expired, :repeat

    def initialize(repeat, interval, *args, &block)
      if (interval < 0.5)
        @interval         = 0.5
      else
        @interval         = interval
      end

      @uuid               = SecureRandom.uuid
      @repeat             = repeat
      @last               = Time.now
      @callback_object    = nil
      @callback_method    = nil
      @type               = nil
      @args               = nil
      @block              = nil
      @thread             = nil
      @running            = false

      if (block_given?)
        @type             = :block
        @block            = block
        @args             = *args
      else
        @type             = :callback
        @callback_object  = args.shift
        @callback_method  = args.shift
        @args             = *args
      end
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

    def execute()
      @running = true
      if (@type == :block)
        if (@args.count > 1)
          @block.call(*@args)
        elsif (@args.count == 1)
          @block.call(@args[0])
        else
          @block.call
        end
      elsif (@type == :callback)
        if (@args.count > 1)
          @callback_object.public_send(@callback_method.to_sym, *@args)
        elsif (@args.count == 1)
          @callback_object.public_send(@callback_method.to_sym, @args[0])
        else
          @callback_object.public_send(@callback_method.to_sym)
        end
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
