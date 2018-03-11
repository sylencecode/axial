#!/usr/bin/env ruby

require 'sequel'
require 'models/nick.rb'

class RSSError < Exception
end

module Axial
  module Models
    class RSSFeed < Sequel::Model
      many_to_one :nick

      def self.upsert(feed_name, url, nick_model)
        if (!nick_model.kind_of?(Models::Nick))
          raise(NickObjectError, "#{self.class}.upsert requires a Models::Nick object")
        end
        rss_model = self[name: feed_name.downcase, url: url.downcase] # find by matching url and name
        if (rss_model.nil?)
          rss_model = self[name: feed_name.downcase] # find by matching name
        end
        if (rss_model.nil?)
          rss_model = self[url: url.downcase] # find by matching url
        end
        if (rss_model.nil?) # insert
          rss_model = self.create(url: url.downcase, pretty_url: url, name: feed_name.downcase, pretty_name: feed_name, nick_id: nick_model[:id], enabled: true)
        else # update
          rss_model.update(url: url.downcase, pretty_url: url, name: feed_name.downcase, pretty_name: feed_name)
        end
        return rss_model
      end
    end
  end
end
