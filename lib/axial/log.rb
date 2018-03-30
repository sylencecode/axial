require 'logger'


module Axial
  class Logger
    def initialize(dest)
      @monitor = Monitor.new
      @logger = ::Logger.new(dest)
      @logger.formatter = proc do |severity, time, unused, message|
        puts "#{time.strftime('%m/%d/%y %H:%M:%S')} [#{severity.center(8)}] #{message}"
      end
    end

    def level=(level)
      @logger.level = level
    end

    def level()
      return @logger.level
    end

    def debug(text)
      @monitor.synchronize do
        @logger.debug(text)
      end
    end

    def info(text)
      @monitor.synchronize do
        @logger.info(text)
      end
    end

    def warn(text)
      @monitor.synchronize do
        @logger.warn(text)
      end
    end

    def error(text)
      @monitor.synchronize do
        @logger.error(text)
      end
    end

    def fatal(text)
      @monitor.synchronize do
        @logger.fatal(text)
      end
    end
  end
end

LOGGER = Axial::Logger.new(STDOUT)
LOGGER.level = ::Logger::DEBUG
