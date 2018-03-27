require 'axial/timer'

module Axial
  module Handlers
    class TimerHandler
      attr_reader :timers

      def initialize()
        @thread = nil
        @timers = []
      end

      def include?(timer)
        return @timers.select { |tmp_timer| tmp_timer.id == timer.id }.any?
      end

      def delete(dead_timer)
        remove(dead_timer)
      end

      def kill(dead_timer)
        remove(dead_timer)
      end

      def remove(dead_timer)
        @timers.select { |timer| timer.id == dead_timer.id }.each do |timer|
          if (!timer.thread.nil?)
            timer.thread.kill
          end
        end
        @timers.delete_if { |timer| timer.id == dead_timer.id }
      end

      def start()
        @timers.clear
        @running = true
        @thread  = Thread.new do
          while (@running)
            begin
              sleep 1
              @timers.each do |timer|
                # execute <= time.now
                # remove it or reset the time on it if repeating
                # remove any other expired
                if (Time.now - timer.interval >= timer.last)
                  timer.thread = Thread.new do
                    begin
                      timer.execute
                    rescue Exception => ex
                      LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
                      ex.backtrace.each do |i|
                        LOGGER.error(i)
                      end
                    end
                  end
                  if (!timer.repeat?)
                    timer.expired = true
                  end
                end
              end
              @timers.delete_if { |timer| timer.expired? }
            rescue Exception => ex
              LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
              ex.backtrace.each do |i|
                LOGGER.error(i)
              end
            end
          end
        end
      end

      def stop()
        @timers.clear
        @running = false
        @thread.kill
      end

      def method_missing(method, *args, &block)
        case method.to_s
          when /^every_second$/
            timer = Timer.new(true, 1, *args, &block)
          when /^every_(\d+)_seconds$/
            timer = Timer.new(true, Regexp.last_match[1].to_i, *args, &block)
          when /^every_minute$/
            timer = Timer.new(true, 60, *args, &block)
          when /^every_(\d+)_minutes$/
            timer = Timer.new(true, Regexp.last_match[1].to_i * 60, *args, &block)
          when /^every_hour$/
            timer = Timer.new(true, 3600, *args, &block)
          when /^every_(\d+)_hours$/
            timer = Timer.new(true, Regexp.last_match[1].to_i * 3600, *args, &block)
          when /^in_second$/, /^in_1_second$/
            timer = Timer.new(false, 1, *args, &block)
          when /^in_(\d+)_seconds$/
            timer = Timer.new(false, Regexp.last_match[1].to_i, *args, &block)
          when /^in_minute$/, /^in_1_minute$/
            timer = Timer.new(false, 60, *args, &block)
          when /^in_(\d+)_minutes$/
            timer = Timer.new(false, Regexp.last_match[1].to_i * 60, *args, &block)
          when /^in_hour$/, /^in_1_hour$/
            timer = Timer.new(false, 3600, *args, &block)
          when /^in_(\d+)_hours$/
            timer = Timer.new(false, Regexp.last_match[1].to_i * 3600, *args, &block)
          else
            super
        end
        @timers.push(timer)
        return timer
      end
    end
  end
end
