require 'axial/bot'
require 'axial/irc_types/nick'

module Axial
  module IRCTypes
    class Mode
      attr_reader   :bans, :unbans, :ops, :deops, :voices, :devoices

      def initialize()
        @max_modes            = Bot.server.max_modes
        @bans                 = []
        @unbans               = []
        @invite_only          = :unknown
        @keyword              = { type: :unknown, value: '' }
        @limit                = { type: :unknown, value: '' }
        @moderated            = :unknown
        @no_outside_messages  = :unknown
        @ops                  = []
        @deops                = []
        @secret               = :unknown
        @topic_ops_only       = :unknown
        @voices               = []
        @devoices             = []
      end

      def channel_modes()
        list = []
        list.push(:bans) if (@bans.any?)
        list.push(:unbans) if (@unbans.any?)
        list.push(:invite_only) if (@invite_only != :unknown)
        list.push(:keyword) if (@keyword[:type] != :unknown)
        list.push(:limit) if (@limit[:type] != :unknown)
        list.push(:moderated) if (@moderated != :unknown)
        list.push(:no_outside_messages) if (@no_outside_messages != :unknown)
        list.push(:ops) if (@ops.any?)
        list.push(:deops) if (@deops.any?)
        list.push(:secret) if (@secret != :unknown)
        list.push(:topic_ops_only) if (@topic_ops_only != :unknown)
        list.push(:voices) if (@voices.any?)
        list.push(:devoices) if (@voices.any?)
        return list
      end

      def topic_ops_only=(value)
        if (value)
          @topic_ops_only = :set
        else
          @topic_ops_only = :unset
        end
      end

      def topic_ops_only?
        return (@topic_ops_only == :set)
      end

      def no_outside_messages=(value)
        if (value)
          @no_outside_messages = :set
        else
          @no_outside_messages = :unset
        end
      end

      def no_outside_messages?
        return (@no_outside_messages == :set)
      end

      def invite_only=(value)
        if (value)
          @invite_only = :set
        else
          @invite_only = :unset
        end
      end

      def invite_only?
        return (@invite_only == :set)
      end

      def moderated=(value)
        if (value)
          @moderated = :set
        else
          @moderated = :unset
        end
      end

      def moderated?
        return (@moderated == :set)
      end

      def secret=(value)
        if (value)
          @secret = :set
        else
          @secret = :unset
        end
      end

      def secret?
        return (@secret == :set)
      end

      def keyword?()
        return (!keyword.empty?)
      end

      def keyword()
        retval = ''
        if (@keyword[:type] == :set && !@keyword[:value].empty?)
          retval = @keyword[:value]
        end
        return retval
      end

      def set_keyword(keyword)
        @keyword = { type: :set, value: keyword}
      end

      def unset_keyword(keyword)
        @keyword = { type: :unset, value: keyword}
      end

      def limit?()
        return (limit > 0)
      end

      def limit()
        retval = 0
        if (@limit[:type] == :set)
          if (@limit[:value].is_a?(String) && !@limit[:value].empty?)
            retval = @limit[:value].to_i
          elsif(@limit[:value] > 0)
            retval = @limit[:value]
          end
        end
        return retval
      end

      def limit=(limit)
        if (limit < 1)
          @limit = { type: :unset, value: ''}
        else
          @limit = { type: :set, value: limit}
        end
      end

      def op(nick_or_name)
        if (nick_or_name.is_a?(IRCTypes::Nick))
          nickname = nick_or_name.name
        else
          nickname = nick_or_name
        end
        @ops.push(nickname)
      end

      def deop(nick_or_name)
        if (nick_or_name.is_a?(IRCTypes::Nick))
          nickname = nick_or_name.name
        else
          nickname = nick_or_name
        end
        @deops.push(nickname)
      end

      def voice(nick_or_name)
        if (nick_or_name.is_a?(IRCTypes::Nick))
          nickname = nick_or_name.name
        else
          nickname = nick_or_name
        end
        @voices.push(nickname)
      end

      def devoice(nick_or_name)
        if (nick_or_name.is_a?(IRCTypes::Nick))
          nickname = nick_or_name.name
        else
          nickname = nick_or_name
        end
        @devoices.push(nickname)
      end

      def ban(mask)
        @bans.push(mask)
      end

      def unban(mask)
        @unbans.push(mask)
      end

      def parse_string(raw_mode)
        if (raw_mode =~ /(\S+)(.*)/)
          modes_string, values_string = Regexp.last_match.captures
        else
          return self
        end

        unsets = []
        sets = []

        values = values_string.strip.split(/\s+/)
        modes = modes_string.scan(/\S/)

        action = :set

        while (modes.length > 0)
          letter = modes[0]
          who = ''
          case letter
            when '-'
              action = :unset
              modes.shift
              next
            when '+'
              action = :set
              modes.shift
              next
            when 'l'
              if (action == :set)
                who = values.shift
              end
              modes.shift
            when 'b', 'k', 'o', 'v'
              # grab value
              modes.shift
              who = values.shift
            when 'a', 'd', 'e', 'f', 'h', 'I', 'J', 'L', 'O', 'p', 'q', 'R'
              # discard value
              modes.shift
              values.shift
              next
            else
              modes.shift
          end

          if (action == :set)
            if (unsets.select{ |i| i[:mode] == letter && i[:value] == who }.any?)
              unsets.delete_if{ |i| i[:mode] == letter && i[:value] == who }
            else
              if (sets.select{ |i| i[:mode] == letter && i[:value] == who }.empty?)
                sets.push(mode: letter, value: who)
              end
            end
          else
            if (sets.select{ |i| i[:mode] == letter && i[:value] == who }.any?)
              sets.delete_if{ |i| i[:mode] == letter && i[:value] == who }
            else
              if (unsets.select{ |i| i[:mode] == letter && i[:value] == who }.empty?)
                unsets.push(mode: letter, value: who)
              end
            end
          end
        end

        sets.each do |set|
          case set[:mode]
            when 'b'
              ban(set[:value])
            when 'i'
              @invite_only = :set
            when 'k'
              @keyword = { type: :set, value: set[:value] }
            when 'l'
              @limit = { type: :set, value: set[:value] }
            when 'm'
              @moderated = :set
            when 'n'
              @no_outside_messages = :set
            when 'o'
              op(set[:value])
            when 's'
              @secret = :set
            when 't'
              @topic_ops_only = :set
            when 'v'
              voice(set[:value])
          end
        end

        unsets.each do |unset|
          case unset[:mode]
            when 'b'
              unban(unset[:value])
            when 'i'
              @invite_only = :unset
            when 'k'
              @keyword = { type: :unset, value: unset[:value] }
            when 'l'
              @limit = { type: :unset, value: unset[:value] }
            when 'm'
              @moderated = :unset
            when 'n'
              @no_outside_messages = :unset
            when 'o'
              deop(unset[:value])
            when 's'
              @secret = :unset
            when 't'
              @topic_ops_only = :unset
            when 'v'
              devoice(unset[:value])
          end
        end
      end

      def merge_string(raw_mode)
        if (raw_mode =~ /(\S+)(.*)/)
          modes_string, values_string = Regexp.last_match.captures
        else
          return self
        end

        unsets = []
        sets = []

        values = values_string.strip.split(/\s+/)
        modes = modes_string.scan(/\S/)

        action = :set

        while (modes.length > 0)
          letter = modes[0]
          who = ''
          case letter
            when '-'
              action = :unset
              modes.shift
              next
            when '+'
              action = :set
              modes.shift
              next
            when 'l'
              if (action == :set)
                who = values.shift
              end
              modes.shift
            when 'b', 'k', 'o', 'v'
              # grab value
              modes.shift
              who = values.shift
            when 'a', 'd', 'e', 'f', 'h', 'I', 'J', 'L', 'O', 'p', 'q', 'R'
              # discard value
              modes.shift
              values.shift
              next
            else
              modes.shift
          end

          if (action == :set)
            if (unsets.select{ |i| i[:mode] == letter && i[:value] == who }.any?)
              unsets.delete_if{ |i| i[:mode] == letter && i[:value] == who }
            else
              if (sets.select{ |i| i[:mode] == letter && i[:value] == who }.empty?)
                sets.push(mode: letter, value: who)
              end
            end
          else
            if (sets.select{ |i| i[:mode] == letter && i[:value] == who }.any?)
              sets.delete_if{ |i| i[:mode] == letter && i[:value] == who }
            else
              if (unsets.select{ |i| i[:mode] == letter && i[:value] == who }.empty?)
                unsets.push(mode: letter, value: who)
              end
            end
          end
        end

        sets.each do |set|
          case set[:mode]
            when 'i'
              @invite_only = :set
            when 'k'
              @keyword = { type: :set, value: set[:value] }
            when 'l'
              @limit = { type: :set, value: set[:value] }
            when 'm'
              @moderated = :set
            when 'n'
              @no_outside_messages = :set
            when 's'
              @secret = :set
            when 't'
              @topic_ops_only = :set
          end
        end

        unsets.each do |unset|
          case unset[:mode]
            when 'i'
              @invite_only = :unknown
            when 'k'
              @keyword = { type: :unknown, value: '' }
            when 'l'
              @limit = { type: :unknown, value: '' }
            when 'm'
              @moderated = :unknown
            when 'n'
              @no_outside_messages = :unknown
            when 's'
              @secret = :unknown
            when 't'
              @topic_ops_only = :unknown
          end
        end
      end

      def emoty?()
        return to_string_array.empty?
      end

      def any?()
        return to_string_array.any?
      end

      def to_string_array()
        sets = []
        unsets = []
        @bans.each do |value|
          sets.push({mode: 'b', value: value})
        end
        @unbans.each do |value|
          unsets.push({mode: 'b', value: value})
        end

        if (@invite_only == :set)
          sets.push(mode: 'i', value: '')
        elsif (@invite_only == :unset)
          unsets.push(mode: 'i', value: '')
        end

        if (@keyword[:type] == :set)
          sets.push(mode: 'k', value: @keyword[:value])
        elsif (@keyword[:type] == :unset)
          unsets.push(mode: 'k', value: @keyword[:value])
        end

        if (@limit[:type] == :set)
          sets.push(mode: 'l', value: @limit[:value].to_s)
        elsif (@limit[:type] == :unset)
          unsets.push(mode: 'l', value: '')
        end

        if (@moderated == :set)
          sets.push(mode: 'm', value: '')
        elsif (@moderated == :unset)
          unsets.push(mode: 'm', value: '')
        end

        if (@no_outside_messages == :set)
          sets.push(mode: 'n', value: '')
        elsif (@no_outside_messages == :unset)
          unsets.push(mode: 'n', value: '')
        end

        @ops.each do |value|
          sets.push(mode: 'o', value: value)
        end

        @deops.each do |value|
          unsets.push(mode: 'o', value: value)
        end

        if (@secret == :set)
          sets.push(mode: 's', value: '')
        elsif (@secret == :unset)
          unsets.push(mode: 's', value: '')
        end

        if (@topic_ops_only == :set)
          sets.push(mode: 't', value: '')
        elsif (@topic_ops_only == :unset)
          unsets.push(mode: 't', value: '')
        end

        @voices.each do |value|
          sets.push(mode: 'v', value: value)
        end

        @devoices.each do |value|
          unsets.push(mode: 'v', value: value)
        end

        out = []
        counter = 0
        mode_string = ''
        values_string = ''
        action = '+'
        while (sets.count > 0)
          counter += 1
          set = sets.shift

          if (!mode_string.start_with?(action))
            mode_string += action
          end

          mode_string += set[:mode]
          values_string += set[:value].empty? ? '' : "#{set[:value]} "

          if (counter == @max_modes)
            out_string = "#{mode_string.strip}#{values_string.empty? ? '' : " "}#{values_string.strip}"
            out.push(out_string)
            out_string = ''
            mode_string = ''
            values_string = ''
            counter = 0
          end
        end

        switched = false
        action = '-'
        while (unsets.count > 0)
          counter += 1
          unset = unsets.shift
          if (!mode_string.start_with?(action))
            if (!switched)
              mode_string += action
              switched = true
            end
          end

          mode_string += unset[:mode]
          values_string += unset[:value].empty? ? '' : "#{unset[:value]} "

          if (counter == @max_modes)
            out_string = "#{mode_string.strip}#{values_string.empty? ? '' : " "}#{values_string.strip}"
            out.push(out_string)
            out_string = ''
            mode_string = ''
            values_string = ''
            counter = 0
            switched = false
          end
        end
        out_string = "#{mode_string.strip}#{values_string.empty? ? '' : " "}#{values_string.strip}"
        if (!out_string.empty?)
          out.push(out_string)
        end
        return out
      end
    end
  end
end
