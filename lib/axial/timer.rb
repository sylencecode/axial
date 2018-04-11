require 'securerandom'

module Axial
  class TimerError < StandardError
  end

  class Timer
    attr_reader     :uuid, :last, :type, :interval
    attr_accessor   :thread
    attr_writer     :expired, :repeat

    def initialize(repeat, interval, *args, &block)
      if (interval <= 0)
        raise(TimerError, 'invalid duration')
      end

      @uuid               = SecureRandom.uuid
      @interval           = interval
      @repeat             = repeat
      @callback_object    = nil
      @callback_method    = nil
      @type               = nil
      @args               = nil
      @block              = nil
      @last = Time.now
      @thread             = nil

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

    def expired?()
      return @expired
    end

    def repeat?()
      return @repeat
    end

    def execute()
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
      @last = Time.now
    rescue Exception => ex
      LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
      ex.backtrace.each do |i|
        LOGGER.error(i)
      end
    end
  end
end
