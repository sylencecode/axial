$stdout.sync = true
$stderr.sync = true

gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

module Axial
  module API
    module WebOfTrust
      REST_API = 'https://api.mywot.com'
      module V0_4
        REST_API = API::WebOfTrust::REST_API + '/0.4'
        class PublicLinkJSON2
          @rest_api = API::WebOfTrust::V0_4::REST_API + '/public_link_json2'
          @api_key  = 'f204e49afeeb0fd892e3a2643ceb1b7ea9e64a5e'

          def self.get_rating(in_uri)
            if (in_uri.is_a?(String))
              uri = in_uri.strip
              if (uri.empty?)
                raise(ArgumentError, "#{self.class}: empty uri")
              elsif (!(uri =~ URI.regexp))
                raise(ArgumentError, "#{self.class}: invalid uri: #{in_uri.inspect}")
              end
            else
              raise(ArgumentError, "#{self.class}: Invalid object provided: #{in_uri.class}")
            end

            site_uri       = URI.parse(uri)
            site_host      = site_uri.host.downcase

            params         = Hash.new
            params[:key]   = @api_key
            params[:hosts] = site_host + '/'

            rest_endpoint       = URI.parse(@rest_api)
            rest_endpoint.query = URI.encode_www_form(params)

            response            = RestClient::Request.execute(method: :get, url: rest_endpoint.to_s, verify_ssl: false)
            json                = JSON.parse(response)

            warnings            = []

            if (json.key?(site_host))
              site_data = json[site_host]
              if (site_data.key?('categories') && site_data['categories'].is_a?(Hash))
                site_data['categories'].each do |category, confidence|
                  if (confidence > 10)
                    case category.to_i
                      when 100..199
                        if (!warnings.include?('harmful'))
                          warnings.push('harmful')
                        end
                      when 201..299
                        if (!warnings.include?('suspicious'))
                          warnings.push('suspicious')
                        end
                      when 400..403
                        if (!warnings.include?('NSFW'))
                          warnings.push('NSFW')
                        end
                    end
                  end
                end
              end
            end

            return warnings
          end
        end
      end
    end
  end
end
