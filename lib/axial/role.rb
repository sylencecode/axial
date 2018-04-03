module Axial
  class Role
    @numerics = { root: 5, director: 4, manager: 3, op: 2, friend: 1}
    attr_reader :numeric, :name

    def self.numerics()
      return @numerics
    end

    def initialize(role_name)
      @numeric  = Role.numerics[role_name.to_sym]
      @name     = role_name
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

    def method_missing(method, *args, &block)
      case method
        when :root?, :director?, :manager?, :op?, :friend?
          return @name == method.to_s.gsub(/\?$/, '')
        else
          super
      end
    end
  end
end
