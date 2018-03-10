#!/usr/bin/env ruby

require 'rest-client'
require 'uri'
require 'json'

module Weather
  class Forecast
    attr_accessor :found, :conditions, :high, :humidity, :low, :country, :city, :temp
    def initialize()
      @found = false
      @high = 0
      @humidity = 0
      @city = "Unknown"
      @country = "Unknown"
      @low = 0
      @conditions = [ ]
      @temp = 0
    end
  end

  class Search
    @@weather_key = "12abf075f9281c0a686c8e74ff5a2c6e"
    @@rest_api = "https://api.openweathermap.org/data/2.5/weather"

    def search(query)
      params = Hash.new
      if (query =~ /^\d+$/)
        params[:zip]    = query
      else
        params[:q]      = query
      end
      params[:units]    = "imperial"
      params[:appid]    = @@weather_key

      uri = URI::parse(@@rest_api)
      uri.query = URI.encode_www_form(params)
      forecast = Weather::Forecast.new

      begin
        response = RestClient.get(uri.to_s)
        json = JSON.parse(response)
        puts JSON.pretty_generate(json)
        
        if (json.has_key?('weather') && json['weather'].kind_of?(Array))
          conditions = json['weather']
          conditions.each do |condition|
            forecast.conditions.push(condition['description'])
          end
        else
          forecast.conditions.push("normal")
        end

        if (json.has_key?('main') && json['main'].kind_of?(Hash))
          main = json['main']
          forecast.temp = main['temp'].to_i
          forecast.low =  main['temp_min'].to_i
          forecast.high =  main['temp_max'].to_i
          forecast.humidity = main['humidity'].to_i
          forecast.found = true
        end

        if (json.has_key?('sys') && json['sys'].kind_of?(Hash))
          sys = json['sys']
          forecast.country = sys['country']
        end

        if (json.has_key?('name'))
          forecast.city = json['name']
        end
      rescue Exception => ex
        forecast.found = false
        puts "Weather exception: #{ex.class}: #{ex.message}"
      end
      return forecast
    end
  end
end

app = Weather::Search.new
app.search(ARGV[0])
