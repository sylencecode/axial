module Axial
  module IRCTypes
    class Command
      attr_accessor :command, :args
      def initialize(command, args)
        @command = command
        @args = args
        @split = @args.split(' ')
      end

      def first_argument()
        return one_argument
      end

      def one_argument()
        if (@split.any?)
          return @split.first
        else
          return ''
        end
      end

      def one_plus()
        split_array = @split.clone
        return_array = []
        if (split_array.empty?)
          return_array.push('').push('')
        elsif (split_array.count == 1)
          return_array.push(split_array.shift).push('')
        else
          return_array.push(split_array.shift).push(split_array.join(' '))
        end

        return return_array
      end

      def two_arguments()
        return_array = []
        if (@split.empty?)
          return_array.push('').push('')
        elsif (@split.count == 1)
          return_array.push(@split.first).push('')
        elsif (@split.count >= 2)
          return_array.push(@split.first).push(@split[1])
        end

        return return_array
      end

      def three_arguments()
        return_array = two_arguments
        if (@split.count >= 3)
          return_array.push(@split[2])
        else
          return_array.push('')
        end

        return return_array
      end

      def four_arguments()
        return_array = three_arguments
        if (@split.count >= 4)
          return_array.push(@split[3])
        else
          return_array.push('')
        end

        return return_array
      end
    end
  end
end
