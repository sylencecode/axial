require 'securerandom'

module Axial
  class TimerError < StandardError
  end

  class Timer
    attr_reader :id, :last, :type, :interval

    def initialize(repeat, interval, *args, &block)
      if (interval <= 0)
        raise(TimerError, "invalid duration")
      end

      @id              = SecureRandom.uuid
      @interval = interval
      @repeat   = repeat
      @callback_object = nil
      @callback_method = nil
      @type            = nil
      @args            = nil
      @block           = nil


      @last = Time.now

      if (block_given?)
        @type  = :block
        @block = block
        @args  = *args
      else
        @type            = :callback
        @callback_object = args.shift
        @callback_method = args.shift
        @args            = *args
      end

      if (@repeat)
        puts "executing every #{interval} seconds, first run at #{Time.now + interval}"
      else
        puts "executing in #{interval} seconds, runs at #{Time.now + interval}"
      end
    end

    def expired=(expired)
      @expired = expired
    end

    def expired?()
      return @expired
    end

    def repeat?()
      return @repeat
    end

    def repeat=(repeat)
      @repeat = repeat
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
      puts "Timer error: #{ex.class}: #{ex.message}"
      ex.backtrace.each do |i|
        puts i
      end
    end
  end
end
