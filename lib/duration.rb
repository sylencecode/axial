class Duration
  attr_accessor :hours, :minutes, :seconds
  def initialize()
    @hours = 0
    @minutes = 0
    @seconds = 0
  end

  def to_s()
    if (@hours + @minutes + @seconds == 0)
      duration_string = "unknown duration"
    else
      duration_string = ""
      if (@hours > 0)
        if (!duration_string.empty?)
          duration_string += " "
        end
        duration_string += "#{@hours}h"
      end
      if (@minutes > 0)
        if (!duration_string.empty?)
          duration_string += " "
        end
        duration_string += "#{@minutes}m"
      end
      if (@seconds > 0)
        if (!duration_string.empty?)
          duration_string += " "
        end
        duration_string += "#{@seconds}s"
      end
    end
    return duration_string
  end
end
