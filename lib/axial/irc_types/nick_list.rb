require 'axial/irc_types/nick'

class NickListError < StandardError
end

module Axial
  module IRCTypes
    class NickList
      def initialize(server_interface, channel)
        @server_interface   = server_interface
        @nick_list          = {}
        @channel            = channel
      end

      def rename(old_nick_name, new_nick_name)
        old_key = old_nick_name.downcase
        new_key = new_nick_name.downcase

        if (old_key.nil?)
          raise(NickListError, "cannot rename nick without an old nickname having been provided")
        elsif (!@nick_list.key?(old_key))
          raise(NickListError, "attempted to rename non-existent nick '#{old_key}' on #{@channel.name}, but did have: #{@nick_list.keys.inspect}")
        elsif (new_key.nil?)
          raise(NickListError, "failed to rename '#{old_key}' to '#{new_key}'")
        elsif (@nick_list.key?(new_key))
          raise(NickListError, "attempted to rename '#{old_key}' to already-existing nick '#{new_key}'")
        end

        @nick_list[new_key] = @nick_list.delete(old_key)
        LOGGER.debug("successfully renamed '#{old_nick_name}' to '#{new_nick_name}' on channel #{@channel.name} nicklist")
      end

      def add(nick)
        if (@nick_list.key?(nick.name.downcase))
          raise(NickListError, "attempted to create a duplicate of nick '#{nick.name}'")
        end
        @nick_list[nick.name.downcase] = nick
        return nick
      end

      def create_from_uhost(uhost)
        nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
        if (@nick_list.key?(nick.name.downcase))
          raise(NickListError, "attempted to create a duplicate of nick '#{nick.name}'")
        end
        @nick_list[nick.name.downcase] = nick
        return nick
      end

      def all_nicks()
        return @nick_list.values
      end

      def get_from_uhost(uhost)
        nick = nil
        @nick_list.each do |key, possible_nick|
          if (possible_nick.uhost == uhost)
            nick = possible_nick
            break
          end
        end
        return nick
      end

      def include?(nick_or_name)
        key = nil
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end
        return @nick_list.key?(key)
      end

      def get(nick_or_name)
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end

        if (@nick_list.key?(key))
          nick = @nick_list[key]
          return nick
        else
          raise(NickListError, "nick '#{nick_or_name}' does not exist")
        end
      end

      def count()
        return @nick_list.count
      end

      def get_silent(nick_or_name)
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end

        nick = nil
        if (@nick_list.key?(key))
          nick = @nick_list[key]
        end
        return nick
      end

      def delete(nick_or_name)
        key = nil
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end
        
        if (key.nil? || !@nick_list.key?(key))
          raise(NickListError, "attempted to delete non-existent nick '#{key}' from #{@channel.name}")
        end

        nick_to_delete = @nick_list[key]
        nick_to_delete&.set_voiced(@channel, false)
        nick_to_delete&.set_opped(@channel, false)
        LOGGER.debug("removing #{key} from #{@channel.name} nicklist")
        @nick_list.delete(key)
        return nick_to_delete
      end

      def delete_silent(nick_or_name)
        key = nil
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end
        
        if (key.nil? || !@nick_list.key?(key))
          return
        end

        nick_to_delete = @nick_list[key]
        nick_to_delete&.set_voiced(@channel, false)
        nick_to_delete&.set_opped(@channel, false)
        LOGGER.debug("removing #{key} from #{@channel.name} nicklist")
        @nick_list.delete(key)
        return nick_to_delete
      end

      def clear()
        @nick_list.clear
      end
    end
  end
end
