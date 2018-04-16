#!/usr/bin/env ruby
#
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib')))
require 'axial/models/init'
require 'axial/models/user'
require 'axial/models/mask'
require 'axial/models/rss_feed'

require 'json'
require 'sinatra/base'

module Axial
  class WebApp < Sinatra::Base
    set :port, 4444
    enable :sessions
    configure :production, :development do
      enable :logging
    end

    get '/foo' do
        session[:message] = 'Hello World!'
        redirect to('/bar')
    end

    get '/bar' do
        session[:message]   # => 'Hello World!'
    end

    get '/users' do
      response['Access-Control-Allow-Origin'] = '*'
      dump_users_json
    end
    get '/rss_feeds' do
      response['Access-Control-Allow-Origin'] = '*'
      dump_rss_feeds_json
    end

    def dump_rss_feeds_json()
      rss_feeds = []
      Models::RssFeed.all.each do |rss_feed|
        rss_feeds.push(JSON.parse(rss_feed.to_json))
      end

      return rss_feeds.to_json
    end

    def dump_users_json()
      includes = {
        masks: { except: :user_id },
        seen: { except: :user_id }
      }

      users = []
      Models::User.all.each do |user|
        if (user.name.casecmp('unknown').zero?)
          next
        end

        users.push(JSON.parse(user.to_json(include: includes, except: :password)))
      end

      return users.to_json
    end
  end
end

Axial::WebApp.run!
