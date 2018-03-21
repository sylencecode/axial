require 'axial/irc_types/nick'

class NickListError < StandardError
end

module Axial
  module IRCTypes
    class NickList
      def initialize(server_interface)
        @server_interface = server_interface
        @nick_list = {}
      end

      def rename(old_nick_or_name, new_nick_or_name)
        old_key = nil
        if (old_nick_or_name.is_a?(IRCTypes::Nick))
          old_key = old_nick_or_name.name.downcase
        elsif (old_nick_or_name.is_a?(String))
          old_key = old_nick_or_name.downcase
        end

        new_key = nil
        if (new_nick_or_name.is_a?(IRCTypes::Nick))
          new_key = new_nick_or_name.name.downcase
        elsif (new_nick_or_name.is_a?(String))
          new_key = new_nick_or_name.downcase
        end

        if (old_key.nil? || !@nick_list.has_key?(old_key))
          raise(NickListError, "attempted to rename non-existent nick '#{old_key}'")
        elsif (new_key.nil?)
          raise(NickListError, "failed to rename '#{old_key}' to '#{new_key}'")
        elsif (@nick_list.has_key?(new_key))
          raise(NickListError, "attempted to rename '#{old_key}' to already-existing nick '#{new_key}'")
        end

        @nick_list[new_key] = @nick_list.delete(old_key)
        return @nick_list[new_key]
      end

      def add(nick)
        if (@nick_list.has_key?(nick.name.downcase))
          raise(NickListError, "attempted to create a duplicate of nick '#{nick.name}'")
        end
        @nick_list[nick.name.downcase] = nick
      end

      def create_from_uhost(uhost)
        nick = IRCTypes::Nick.from_uhost(@server_interface, uhost)
        if (@nick_list.has_key?(nick.name.downcase))
          raise(NickListError, "attempted to create a duplicate of nick '#{nick.name}'")
        end
        @nick_list[nick.name.downcase] = nick
        return nick
      end

      def all_nicks()
        return @nick_list.values
      end

      def has_nick?(channel_or_name)
        key = nil
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end
        return @nick_list.has_key?(key)
      end

      def get(nick_name)
        if (@nick_list.has_key?(nick_name.downcase))
          nick = @nick_list[nick_name.downcase]
          return nick
        else
          raise(NickListError, "nick '#{nick_name}' does not exist")
        end
      end

      def delete(nick_or_name)
        key = nil
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end
        
        if (!key.nil? && @nick_list.has_key?(key))
          @nick_list.delete(key)
        else
          raise(NickListError, "attempted to delete non-existent nick '#{key}")
        end
      end

      def delete_silent(nick_or_name)
        key = nil
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end

        if (!key.nil? && @nick_list.has_key?(key))
          LOGGER.debug("removing #{key} from nicklist")
          @nick_list.delete(key)
          puts @nick_list.keys.inspect
        end
      end

      def clear()
        @server_interface.channel_list.clear
      end
    end
  end
end
