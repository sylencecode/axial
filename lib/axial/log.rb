require 'logger'

module Axial
  class Logger
    def initialize(dest)
      @monitor = Monitor.new
      @logger = ::Logger.new(dest)
      @file_logger = ::Logger.new(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'axial.log')), 7, 5242880)
      @logger.formatter = proc do |severity, time, unused, message|
        "#{time.strftime('%m/%d/%y %H:%M:%S')} [#{severity.center(8)}] #{message}\n"
      end
      @file_logger.formatter = proc do |severity, time, unused, message|
        "#{time.strftime('%m/%d/%y %H:%M:%S')} [#{severity.center(8)}] #{message}\n"
      end
    end

    def level=(level)
      @logger.level = level
      @file_logger.level = level
    end

    def level()
      return @logger.level
    end

    def debug(text)
      @monitor.synchronize do
        @logger.debug(text)
        @file_logger.debug(text)
      end
    end

    def info(text)
      @monitor.synchronize do
        @logger.info(text)
        @file_logger.info(text)
      end
    end

    def warn(text)
      @monitor.synchronize do
        @logger.warn(text)
        @file_logger.warn(text)
      end
    end

    def error(text)
      @monitor.synchronize do
        @logger.error(text)
        @file_logger.error(text)
      end
    end

    def fatal(text)
      @monitor.synchronize do
        @logger.fatal(text)
        @file_logger.fatal(text)
      end
    end
  end
end

LOGGER = Axial::Logger.new(STDOUT)
LOGGER.level = ::Logger::DEBUG
