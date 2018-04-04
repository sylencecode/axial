module Axial
  class Role
    @numerics = { root: 5, director: 4, manager: 3, op: 2, friend: 1, basic: 0 }
    attr_reader :numeric, :name

    def self.root()
      return new('root')
    end

    def self.director()
      return new('director')
    end

    def self.manager()
      return new('manager')
    end

    def self.op()
      return new('op')
    end

    def self.friend()
      return new('friend')
    end

    def self.basic()
      return new('basic')
    end

    def self.bot()
      return new('bot')
    end

    def self.numerics()
      return @numerics
    end

    def self.from_possible_name(role_name)
      if (!@numerics.has_key?(role_name.to_sym))
        return nil
      else
        return new(role_name)
      end
    end

    def initialize(role_name)
      @name       = role_name
      if (role_name.nil? || role_name == 'bot')
        @numeric = nil
      else
        @numeric  = Role.numerics[role_name.to_sym]
      end
    end

    def ==(right)
      if (right.is_a?(Symbol))
        return self.numeric == Role.numerics[right]
      else
        return self.numeric == right.numeric
      end
    end

    def <(right)
      if (right.is_a?(Symbol))
        return self.numeric < Role.numerics[right]
      else
        return self.numeric < right.numeric
      end
    end

    def <=(right)
      if (right.is_a?(Symbol))
        return self.numeric <= Role.numerics[right]
      else
        return self.numeric <= right.numeric
      end
    end

    def >(right)
      if (right.is_a?(Symbol))
        return self.numeric > Role.numerics[right]
      else
        return self.numeric > right.numeric
      end
    end

    def >=(right)
      if (right.is_a?(Symbol))
        return self.numeric >= Role.numerics[right]
      else
        return self.numeric >= right.numeric
      end
    end


    def color()
      case @name
        when 'root'
          role_color = Colors.red
        when 'director' 
          role_color = Colors.yellow
        when 'manager' 
          role_color = Colors.cyan
        when 'op' 
          role_color = Colors.blue
        when 'friend' 
          role_color = Colors.reset
        when 'basic' 
          role_color = Colors.gray
      end
    end

    def name_with_color()
      return "#{self.color}#{@name}#{Colors.reset}"
    end

    def plural_name_with_color()
      case @name
        when 'root'
          role_color = Colors.red
          plural_name = 'root users'
        when 'director' 
          role_color = Colors.yellow
          plural_name = 'directors'
        when 'manager' 
          role_color = Colors.cyan
          plural_name = 'managers'
        when 'op' 
          role_color = Colors.blue
          plural_name = 'ops'
        when 'friend' 
          role_color = Colors.reset
          plural_name = 'friends'
        when 'basic' 
          role_color = Colors.gray
          plural_name = 'basic users'
      end
      return "#{role_color}#{plural_name}#{Colors.reset}"
    end

    def plural_name()
      case @name
        when 'root'
          return 'root users'
        when 'basic'
          return 'basic users'
        else
          return "#{@name}s"
      end
    end

    def method_missing(method, *args, &block)
      case method
        when :root?, :director?, :manager?, :op?, :friend?, :basic?
          if (self.name == 'bot')
            return false
          else
            return self >= method.to_s.gsub(/\?$/, '').to_sym
          end
        when :bot?
          return name == 'bot'
        else
          super
      end
    end
  end
end
