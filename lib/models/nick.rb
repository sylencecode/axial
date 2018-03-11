#!/usr/bin/env ruby

require_relative '../nick.rb'
require_relative '../mask_utils.rb'
require_relative 'mask.rb'
require_relative 'seen.rb'
require 'sequel'

class DuplicateNickError < DatabaseError
end

class NickObjectError < DatabaseError
end

module Axial
  module Models

    # note to self: you can use this if your model does not directly imply a table
    # Nick = Class.new(Sequel::Model)
    # class Nick
    #  set_dataset :nicks
    class Nick < Sequel::Model

      many_to_many :masks
      one_to_many :things
      one_to_many :rss_feeds
      one_to_one :seen
      # many_to_many :masks, left_key: :nick_id, right_key: :mask_id, join_table: :masks_nicks
      def possible_masks()
        res = []
        masks.each do |result|
          res.push(result.mask)
        end
        res
      end

      def self.get_if_valid(nick)
        nick_model = self[nick: nick.name.downcase]
        if (!nick.kind_of?(::Axial::Nick))
          raise(NickObjectError, "Attempted to query a nick record for an object type other than Axial::Nick.")
        end

        if (!nick_model.nil? && nick_model.match_mask?(nick.uhost))
          return nick_model
        end
        return nil
      end
    
      def match_mask?(in_mask)
        masks.each do |mask|
          re_mask = MaskUtils::get_mask_regexp(mask.mask)
          puts "checking #{in_mask} against #{re_mask.source}"
          if (re_mask.match(in_mask))
            puts "match|#{self.pretty_nick}|#{in_mask}|#{mask.mask}"
            return true
          end
        end
        return false
      end
    
      def self.get_from_nick(nick)
        if (!nick.kind_of?(::Axial::Nick))
          raise(NickObjectError, "Attempted to query a nick record for an object type other than Axial::Nick.")
        end
        return self[nick: nick.name.downcase]
      end

      def self.create_from_nick(nick)
        if (!nick.kind_of?(::Axial::Nick))
          raise(NickObjectError, "Attempted to create a nick record for an object type other than Axial::Nick.")
        end

        if (!get_from_nick(nick).nil?)
          raise(DuplicateNickError, "Nick #{nick.name} already exists.")
        end
    
        nick_model = Nick.create(nick: nick.name.downcase, pretty_nick: nick.name)
        nick_model.seen = Seen.create(nick_id: nick_model.id, status: 'for the first time', last: Time.now)
        mask_model = Mask.create_or_find(nick.uhost)
        nick_model.add_mask(mask_model)
        return nick_model
    
        # move to after_create
    #    else
        #    update_seen here
    #      nick.seen.status = statuses[i]
    #      nick.seen.last = Time.now
    #      nick.seen.update(status: statuses[i], last: Time.now)
    #    end
    #    db_mask = Mask[mask: Mask.gen_wildcard_mask(masks[i])]
    #    if (mask.nil?)
    #      puts "Creating and mask: #{Mask.gen_wildcard_mask(masks[i])}"
    #      nick.add_mask(Mask.create_from_irc_host(masks[i]))
    #  #    #mask = Mask.create(mask: Mask.gen_wildcard_mask(masks[i]))
    #  #    nick.add_mask(mask)
    #    elsif (!nick.match_mask?(masks[i]))
    #      nick.add_mask(mask)
    #    else
    #      puts "Already had #{masks[i]}"
    #    end
      end
    end
  end
end
