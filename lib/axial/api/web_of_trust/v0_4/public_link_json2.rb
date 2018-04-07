gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'
require 'axial/api/web_of_trust/site_rating'

module Axial
  module API
    module WebOfTrust
     REST_API = 'https://api.mywot.com'
     module V0_4
        REST_API = Axial::API::WebOfTrust::REST_API + '/0.4'
        class PublicLinkJSON2
          @rest_api = Axial::API::WebOfTrust::V0_4::REST_API + '/public_link_json2'
          @api_key = "f204e49afeeb0fd892e3a2643ceb1b7ea9e64a5e"
      
          def self.get_rating(in_uri)
            if (in_uri.is_a?(String))
              uri = in_uri.strip
              if (uri.empty?)
                raise(ArgumentError, "#{self.class}: empty uri")
              elsif (!(uri =~ URI::regexp))
                raise(ArgumentError, "#{self.class}: invalid uri: #{in_uri.inspect}")
              end
            else
              raise(ArgumentError, "#{self.class}: Invalid object provided: #{in_uri.class}")
            end
      
            site_rating = SiteRating.new
            site_uri = URI::parse(uri)
            site_host = site_uri.host.downcase
            params = Hash.new
            params[:key]             = @api_key
            params[:hosts]           = site_host + "/"
      
            rest_endpoint = URI::parse(@rest_api)
            rest_endpoint.query = URI.encode_www_form(params)
      
            got_rating = false
            response = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)
            json = JSON.parse(response)
    
            if (json.has_key?(site_host))
              site_data = json[site_host]
              if (site_data.has_key?('target'))
                site_rating.domain = site_data['target']
                if (site_data.has_key?('0') && site_data['0'].is_a?(Array))
                  trustworthiness = site_data['0']
                  if (trustworthiness.is_a?(Array))
                    site_rating.trustworthiness.rating, site_rating.trustworthiness.confidence = trustworthiness
                  end
                end
                if (site_data.has_key?('categories') && site_data['categories'].is_a?(Hash))
                  site_data['categories'].each do |category, confidence|
                    if (confidence > 10)
                      case category
                        when 100..199
                          puts "NEGATIVE"
                        when 200..299
                          puts "NEGATIVE"
                        when 300..399
                          puts "NEGATIVE"
                        when 400..403
                          puts "NEGATIVE"
                        when 404
                          puts "POSITIVE"
                        when 501
                          puts "POSITIVE"
                      end
                    end
                  end
                end
    
                if (site_data.has_key?('blacklists') && site_data['blacklists'].is_a?(Hash))
                  site_data['blacklists'].each do |blacklist, confidence|
                    if (confidence > 10)
                      site_rating.blacklists.push(blacklist.to_sym)
                    end
                  end
                end
              end
            end
            return site_rating
          end
        end
      end
    end
  end
end
