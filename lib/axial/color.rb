module Axial
  class Color
    @reset = "\x03".freeze

    @color_map = {
        reset:        @reset,
        white:        @reset + '00',
        black:        @reset + '01',
        darkblue:     @reset + '02',
        darkgreen:    @reset + '03',
        red:          @reset + '04',
        darkred:      @reset + '05',
        darkmagenta:  @reset + '06',
        orange:       @reset + '07',
        yellow:       @reset + '08',
        green:        @reset + '09',
        darkcyan:     @reset + '10',
        cyan:         @reset + '11',
        blue:         @reset + '12',
        magenta:      @reset + '13',
        gray:         @reset + '14',
        silver:       @reset + '15'
    }

    def self.respond_to_missing?(method, include_private = false)
      return @color_map.key?(method)
    end

    def self.method_missing(method, *args, &block) # rubocop:disable Metrics/PerceivedComplexity
      if (!@color_map.key?(method))
        super
      end

      text = args.first.clone
      if (text.nil? || text.empty?)
        return @color_map[method]
      end

      if (text.start_with?(' '))
        text.insert(1, @color_map[method])
      else
        text.insert(0, @color_map[method])
      end

      if (text.end_with?(' '))
        text.insert(text.length - 1, @reset)
      else
        text += @reset
      end

      return text
    end

    def self.blue_arrow()
      return @color_map[:gray] + '-' + @color_map[:darkblue] + '-' + @color_map[:blue] + '>' + @reset + ' '
    end

    def self.green_arrow()
      return @color_map[:gray] + '-' + @color_map[:darkgreen] + '-' + @color_map[:green] + '>' + @reset + ' '
    end

    def self.red_arrow()
      return @color_map[:gray] + '-' + @color_map[:darkred] + '-' + @color_map[:red] + '>' + @reset + ' '
    end

    def self.red_arrow_reverse()
      return @color_map[:red] + '<' + @color_map[:darkred] + '-' + @color_map[:gray] + '-' + @reset + ' '
    end

    def self.red_prefix(first_prefix, second_prefix = '')
      prefix = @color_map[:gray] + '[' + @reset + ' ' + @color_map[:red] + first_prefix + @reset + ' '

      if (!second_prefix.empty?)
        prefix += @color_map[:gray] + '::' + @reset + ' ' + @color_map[:darkred] + second_prefix + ' '
      end

      prefix += @color_map[:gray] + ']' + @reset + ' '
      return prefix
    end

    def self.magenta_prefix(first_prefix, second_prefix = '')
      prefix = @color_map[:gray] + '[' + @reset + ' ' + @color_map[:magenta] + first_prefix + @reset + ' '

      if (!second_prefix.empty?)
        prefix += @color_map[:gray] + '::' + @reset + ' ' + @color_map[:darkmagenta] + second_prefix + ' '
      end

      prefix += @color_map[:gray] + ']' + @reset + ' '
      return prefix
    end

    def self.blue_prefix(first_prefix, second_prefix = '')
      prefix = @color_map[:gray] + '[' + @reset + ' ' + @color_map[:blue] + first_prefix + @reset + ' '

      if (!second_prefix.empty?)
        prefix += @color_map[:gray] + '::' + @reset + ' ' + @color_map[:darkblue] + second_prefix + ' '
      end

      prefix += @color_map[:gray] + ']' + @reset + ' '
      return prefix
    end

    def self.green_prefix(first_prefix, second_prefix = '')
      prefix = @color_map[:gray] + '[' + @reset + ' ' + @color_map[:green] + first_prefix + @reset + ' '

      if (!second_prefix.empty?)
        prefix += @color_map[:gray] + '::' + @reset + ' ' + @color_map[:darkgreen] + second_prefix + ' '
      end

      prefix += @color_map[:gray] + ']' + @reset + ' '
      return prefix
    end

    def self.cyan_prefix(first_prefix, second_prefix = '')
      prefix = @color_map[:gray] + '[' + @reset + ' ' + @color_map[:cyan] + first_prefix + @reset + ' '

      if (!second_prefix.empty?)
        prefix += @color_map[:gray] + '::' + @reset + ' ' + @color_map[:darkcyan] + second_prefix + ' '
      end

      prefix += @color_map[:gray] + ']' + @reset + ' '
      return prefix
    end
  end
end
