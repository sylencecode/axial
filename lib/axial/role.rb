require 'axial/color'

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
      if (!@numerics.key?(role_name.to_sym))
        return nil
      end

      return new(role_name)
    end

    def initialize(role_name)
      @name       = role_name
      @numeric    = (role_name.nil? || role_name == 'bot') ? nil : Role.numerics[role_name.to_sym]
    end

    def ==(other)
      if (other.is_a?(Symbol)) # rubocop:disable Style/GuardClause
        return self.numeric == Role.numerics[other]
      else
        return self.numeric == other.numeric
      end
    end

    def <(other)
      if (other.is_a?(Symbol)) # rubocop:disable Style/GuardClause
        return self.numeric < Role.numerics[other]
      else
        return self.numeric < other.numeric
      end
    end

    def <=(other)
      if (other.is_a?(Symbol)) # rubocop:disable Style/GuardClause
        return self.numeric <= Role.numerics[other]
      else
        return self.numeric <= other.numeric
      end
    end

    def >(other)
      if (other.is_a?(Symbol)) # rubocop:disable Style/GuardClause
        return self.numeric > Role.numerics[other]
      else
        return self.numeric > other.numeric
      end
    end

    def >=(other)
      if (other.is_a?(Symbol)) # rubocop:disable Style/GuardClause
        return self.numeric >= Role.numerics[other]
      else
        return self.numeric >= other.numeric
      end
    end

    def color()
      case @name
        when 'root'
          role_color = Color.red
        when 'director'
          role_color = Color.yellow
        when 'manager'
          role_color = Color.cyan
        when 'op'
          role_color = Color.blue
        when 'friend'
          role_color = Color.green
        when 'basic'
          role_color = Color.gray
      end

      return role_color
    end

    def name_with_color()
      return "#{self.color}#{@name}#{Color.reset}"
    end

    def plural_name_with_color() # rubocop:disable Metrics/MethodLength
      case @name
        when 'root'
          role_color = Color.red
          plural_name = 'root users'
        when 'director'
          role_color = Color.yellow
          plural_name = 'directors'
        when 'manager'
          role_color = Color.cyan
          plural_name = 'managers'
        when 'op'
          role_color = Color.blue
          plural_name = 'ops'
        when 'friend'
          role_color = Color.reset
          plural_name = 'friends'
        when 'basic'
          role_color = Color.gray
          plural_name = 'basic users'
      end
      return "#{role_color}#{plural_name}#{Color.reset}"
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

    def respond_to_missing?(method, include_private = false)
      role_methods = %i[root? director? manager? op? friend? basic? bot?]
      return role_methods.include?(method)
    end

    def method_missing(method, *args, &block)
      case method
        when :root?, :director?, :manager?, :op?, :friend?, :basic?
          if (self.name == 'bot') # rubocop:disable Style/GuardClause
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
