require 'axial/timer'

module Axial
  module Handlers
    class TimerHandler
      attr_reader :timers

      def initialize()
        @thread = nil
        @timers = []
      end

      def all_timers()
        return @timers.clone
      end

      def get_from_callback_method(method)
        return @timers.select { |tmp_timer| tmp_timer.callback_method == method }
      end

      def include?(timer)
        if (timer.nil?)
          return false
        end

        return @timers.select { |tmp_timer| tmp_timer.uuid == timer.uuid }.any?
      end

      def delete(dead_timer)
        if (dead_timer.nil?)
          return
        end

        remove(dead_timer)
      end

      def kill(dead_timer)
        if (dead_timer.nil?)
          return
        end

        remove(dead_timer)
      end

      def remove(dead_timer)
        if (dead_timer.nil?)
          return
        end

        @timers.select { |timer| timer.uuid == dead_timer.uuid }.each do |timer|
          if (!timer.thread.nil?)
            timer.thread.kill
          end
        end
        @timers.delete_if { |timer| timer.uuid == dead_timer.uuid }
      end

      def execute_timers() # rubocop:disable Metrics/MethodLength
        sleep 0.1
        @timers.each do |timer|
          if (Time.now - timer.interval < timer.last)
            next
          end

          if (timer.running?)
            next
          end

          timer.last = Time.now
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
        @timers.delete_if(&:expired?)
      end

      def start()
        @timers.clear
        @running = true
        @thread  = Thread.new do
          while (@running)
            begin
              execute_timers
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

      def respond_to_missing?(method, include_private = false)
        method_regexps = [
            /^every_second$/, /^every_(\d+)_seconds$/, /^every_minute$/, /^every_(\d+)_minutes$/,
            /^every_hour$/, /^every_(\d+)_hours$/, /^in_a_tiny_bit$/, /^in_a_bit$/, /^in_second$/, /^in_1_second$/,
            /^in_(\d+)_seconds$/, /^in_minute$/, /^in_1_minute$/, /^in_(\d+)_minutes$/, /^in_hour$/, /^in_1_hour$/,
            /^in_(\d+)_hours$/
        ]

        method_match = Regexp.union(method_regexps)
        return method_match.match?(method.to_s)
      end

      def method_missing(method, *args, &block) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity
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
          when /^in_a_tiny_bit$/
            random_fractional_secs = (SecureRandom.random_number(400) / 100.to_f)
            timer = Timer.new(false, random_fractional_secs, *args, &block)
          when /^in_a_bit$/
            random_fractional_secs = (SecureRandom.random_number(800) / 100.to_f) + 2.0
            timer = Timer.new(false, random_fractional_secs, *args, &block)
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
