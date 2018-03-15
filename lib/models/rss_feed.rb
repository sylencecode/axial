require 'sequel'
require 'models/user.rb'

class RSSError < StandardError
end

module Axial
  module Models
    class RSSFeed < Sequel::Model
      many_to_one :user

      def self.upsert(feed_name, url, user_model)
        if (!user_model.kind_of?(Models::User))
          raise(UserObjectError, "#{self.class}.upsert requires a Models::User object")
        end
        rss_model = self[name: feed_name.downcase, url: url.downcase] # find by matching url and name
        if (rss_model.nil?)
          rss_model = self[name: feed_name.downcase] # find by matching name
        end
        if (rss_model.nil?)
          rss_model = self[url: url.downcase] # find by matching url
        end
        if (rss_model.nil?) # insert
          rss_model = self.create(url: url.downcase, pretty_url: url, name: feed_name.downcase, pretty_name: feed_name, user_id: user_model[:id], enabled: true, last_ingest: Time.now)
        else # update
          rss_model.update(url: url.downcase, pretty_url: url, name: feed_name.downcase, pretty_name: feed_name, last_ingest: Time.now)
        end
        return rss_model
      end
    end
  end
end
