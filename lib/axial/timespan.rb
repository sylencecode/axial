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

    def initialize(_time1, _time2)
      if (_time1 > _time2)
        now = _time1
        later = _time2
      else
        now = _time2
        later = _time1
      end
      total_seconds = (now - later).to_i
      minute = 60
      hour = minute * 60
      day = 24 * hour

      remaining = 0
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
      if ( @hours.positive? || @minutes.positive?)
        elapsed = "#{@minutes}m#{elapsed}"
      end
      if ( @days.positive? || @hours.positive?)
        elapsed = "#{@hours}h#{elapsed}"
      end
      if ( @days.positive?)
        elapsed = "#{@days}d#{elapsed}"
      end
      return elapsed
    end

    def approximate_to_s()
      # order largest to smallest
      elapsed = ''
      if (@days == 1)
        if (@hours >= 12)
          elapsed = 'about 2 days'
        else
          elapsed = 'about a day'
        end
      elsif (@days > 1)
        if (@days <= 3)
          if (@hours >= 12)
            elapsed = "around #{@days + 1} days"
          else
            elapsed = "around #{@days} days"
          end
        else
          elapsed = "#{@days} days"
        end
      elsif (@hours == 1)
        if (@minutes >= 40)
          elapsed = 'about 2 hours'
        elsif (@minutes > 15)
          elapsed = 'about an hour and a half'
        else
          elapsed = 'about an hour'
        end
      elsif (@hours > 1)
        if (@minutes > 30)
          elapsed = "about #{@hours + 1} hours"
        else
          elapsed = "about #{@hours} hours"
        end
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
