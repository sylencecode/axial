module Axial
  class TimeSpan
    attr_accessor :days, :hours, :minutes, :seconds

    def self.empty()
      timespan = self.new(Time.now, Time.now)
      timespan.days = 0
      timespan.hours = 0
      timespan.minutes = 0
      timespan.seconds = 0
      return timespan
    end

    def self.from_pt_string(pt_string)
      timespan = empty

      if (pt_string =~ /^pt(.*)/)
        raw_duration = Regexp.last_match[1]

        if (raw_duration =~ /(\d+)h/)
          timespan.hours = Regexp.last_match[1].to_i
        end

        if (raw_duration =~ /(\d+)m/)
          timespan.minutes = Regexp.last_match[1].to_i
        end

        if (raw_duration =~ /(\d+)s/)
          timespan.seconds = Regexp.last_match[1].to_i
        end
      end

      return timespan
    end

    def initialize(left_time, right_time)
      if (left_time > right_time)
        now = left_time
        later = right_time
      else
        now = right_time
        later = left_time
      end
      total_seconds = (now - later).to_i
      minute = 60
      hour = minute * 60
      day = 24 * hour

      @days = total_seconds / day
      remaining = total_seconds % day
      @hours = remaining / hour
      remaining = total_seconds % hour
      @minutes = remaining / minute
      remaining = total_seconds % minute
      @seconds = remaining
    end

    def short_to_s()
      elapsed = "#{@seconds}s"
      if (@hours.positive? || @minutes.positive?)
        elapsed = "#{@minutes}m#{elapsed}"
      end
      if (@days.positive? || @hours.positive?)
        elapsed = "#{@hours}h#{elapsed}"
      end
      if (@days.positive?)
        elapsed = "#{@days}d#{elapsed}"
      end
      return elapsed
    end

    def approximate_to_s() # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      # order largest to smallest
      elapsed = ''
      if (@days == 1)
        elapsed = (@hours >= 12) ? 'about 2 days' : 'about a day'
      elsif (@days > 1)
        if (@days <= 3) # rubocop:disable Style/ConditionalAssignment
          elapsed = (@hours >= 12) ? "about #{@days + 1} days" : "about #{@days} days"
        else
          elapsed = "#{@days} days"
        end
      elsif (@hours == 1)
        if (@minutes >= 40) # rubocop:disable Style/ConditionalAssignment
          elapsed = 'about 2 hours'
        elsif (@minutes > 15)
          elapsed = 'about an hour and a half'
        else
          elapsed = 'about an hour'
        end
      elsif (@hours > 1)
        elapsed = (@minutes > 30) ? "about #{@hours + 1} hours" : "about #{@hours} hours"
      elsif (@minutes >= 45)
        elapsed = 'about an hour'
      elsif (@minutes > 37)
        elapsed = 'about 45 minutes'
      elsif (@minutes > 19)
        elapsed = 'about half an hour'
      elsif (@minutes > 10)
        elapsed = 'about 15 minutes'
      elsif (@minutes > 1)
        elapsed = "about #{@minutes} minutes"
      elsif (@minutes == 1)
        elapsed = 'about a minute'
      else
        elapsed = 'less than a minute'
      end
      return elapsed
    end
  end
end
