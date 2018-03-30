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

      def rename(old_nick_name, new_nick_name)
        old_key = old_nick_name.downcase
        new_key = new_nick_name.downcase

        if (old_key.nil? || !@nick_list.has_key?(old_key))
          raise(NickListError, "attempted to rename non-existent nick '#{old_key}'")
        elsif (new_key.nil?)
          raise(NickListError, "failed to rename '#{old_key}' to '#{new_key}'")
        elsif (@nick_list.has_key?(new_key))
          raise(NickListError, "attempted to rename '#{old_key}' to already-existing nick '#{new_key}'")
        end

        @nick_list[new_key] = @nick_list.delete(old_key)
      end

      def add(nick)
        if (@nick_list.has_key?(nick.name.downcase))
          raise(NickListError, "attempted to create a duplicate of nick '#{nick.name}'")
        end
        @nick_list[nick.name.downcase] = nick
        return nick
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
        return @nick_list.has_key?(key)
      end

      def get(nick_or_name)
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end

        if (@nick_list.has_key?(key))
          nick = @nick_list[key]
          return nick
        else
          raise(NickListError, "nick '#{nick_name}' does not exist")
        end
      end

      def get_silent(nick_or_name)
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end

        nick = nil
        if (@nick_list.has_key?(key))
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

        deleted_nick = @nick_list[key]

        if (!key.nil? && @nick_list.has_key?(key))
          @nick_list.delete(key)
        else
          raise(NickListError, "attempted to delete non-existent nick '#{key}")
        end
        return deleted_nick
      end

      def delete_silent(nick_or_name)
        key = nil
        if (nick_or_name.is_a?(IRCTypes::Nick))
          key = nick_or_name.name.downcase
        elsif (nick_or_name.is_a?(String))
          key = nick_or_name.downcase
        end

        deleted_nick = @nick_list[key]

        if (!key.nil? && @nick_list.has_key?(key))
          LOGGER.debug("removing #{key} from nicklist")
          @nick_list.delete(key)
        end
        return deleted_nick
      end

      def clear()
        @server_interface.channel_list.clear
      end
    end
  end
end
