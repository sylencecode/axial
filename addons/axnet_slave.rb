require 'yml'
require 'axial/addon'

module Axial
  module Addons
    class AxnetSlave < Axial::Addon

      def initialize(bot)
        super

        @name    = 'axnet slave'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        @port           = 34567
        #on_startup  :start_slave_thread
      end
      @slave_thread  = nil
      @connection     = nil
      @running      = false
    end

    def a_thing()
      users = []
      Axial::Models::User.each do |user|
        netuser = Axial::BotNet::User.from_model(user)
        puts netuser.inspect
        users.push(netuser)
      end
      raw_yml = YAML.dump(users)
      packet = raw_yml.gsub(/\n/, "\0")
      client.puts(packet)
      puts "end stream"
    rescue OpenSSL::SSL::SSLError => ex
      puts "#{ex.class}: #{ex.message}"
      puts "#{ex.inspect}"
    end

    def stop_slave_thread()
      @running = false
      if (!@slave_thread.nil?)
        @slave_thread.kill
      end
    end

    def start_slave_thread()
      @running = true
      @ingest_thread = Thread.new do
        while (@running)
          begin
          #    end
          #  end
          rescue Exception => ex
            LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
            ex.backtrace.each do |i|
              LOGGER.error(i)
            end
          ensure
            sleep 10
          end
        end
      end
    end

    def before_reload()
      super
      LOGGER.info("#{self.class}: shutting down connection to master")
      stop_slave_thread
      @slave_thread = nil
    end
  end
end
