gem 'ohai'
require 'ohai'

module Axial
  module Axnet
    class SystemInfo
      attr_reader   :os, :cpu_model, :cpu_mhz, :cpu_logical_processors, :mem_free, :mem_total, :kernel_name,
                    :kernel_release, :kernel_machine, :ruby_version, :ruby_patch_level, :ruby_platform

      attr_accessor :startup_time, :addons, :latest_commit, :server_info, :uhost

      def initialize(data_hash)
        @os                       = data_hash[:os]
        @cpu_model                = data_hash[:cpu][:model]
        @cpu_mhz                  = data_hash[:cpu][:mhz]
        @cpu_logical_processors   = data_hash[:cpu][:logical_processors]
        @mem_free                 = data_hash[:memory][:free]
        @mem_total                = data_hash[:memory][:total]
        @kernel_name              = data_hash[:kernel][:name]
        @kernel_release           = data_hash[:kernel][:release]
        @kernel_machine           = data_hash[:kernel][:machine]
        @ruby_version             = RUBY_VERSION
        @ruby_patch_level         = RUBY_PATCHLEVEL
        @ruby_platform            = RUBY_PLATFORM
        @startup_time             = nil
        @addons                   = []
        @latest_commit            = nil
        @server_info              = 'unknown_server:unknown_port'
        @uhost                    = 'unknown'
      end

      def self.from_environment()
        plugins = %w[platform cpu uptime memory hostnamectl hardware]
        ohai_parser = Ohai::System.new
        ohai_parser.load_plugins
        ohai_parser.run_plugins(true, plugins)
        ohai_hash = ohai_parser.data
        data_hash = {}
        data_hash[:uptime]    = ohai_hash['uptime']
        data_hash[:os]        = get_os_string(ohai_hash)
        data_hash[:cpu]       = parse_cpu(ohai_hash['cpu'])
        data_hash[:memory]    = parse_memory(ohai_hash['memory'])
        data_hash[:kernel]    = parse_kernel(ohai_hash['kernel'])
        return new(data_hash)
      end

      def self.convert_memory_to_mb(memory_string)
        case memory_string.to_s
          when /(\d+)kb/i
            parsed = (Regexp.last_match[1].to_f / 1024).round(0)
          when /(\d+)mb/i
            parsed = Regexp.last_match[1].to_f.round(0)
          when /(\d+)gb/i
            parsed = Regexp.last_match[1].to_i * 1024
          when /(\d+)/
            parsed = (Regexp.last_match[1].to_f / 1024 / 1024).round(0)
          else
            parsed = 'unknown'
        end
        return parsed.to_s
      end

      def self.parse_cpu(cpu_hash)
        model_name    = 'unknown'
        total         = 'unknown'
        mhz           = 'unknown'
        if (cpu_hash.key?('total'))
          total       = cpu_hash['total'].to_i
        else
          total       = 1
        end
        if (cpu_hash.key?('0'))
          mhz         = cpu_hash['0']['mhz'].to_i
          model_name  = cpu_hash['0']['model_name']
        elsif (cpu_hash.key?('model_name'))
          mhz         = cpu_hash['mhz'].to_i
          model_name  = cpu_hash['model_name']
        end
        new_cpu_hash = { model: model_name, logical_processors: total, mhz: mhz }
        return new_cpu_hash
      end

      def self.get_os_string(ohai_hash)
        if (ohai_hash.key?('hostnamectl') && ohai_hash['hostnamectl'].key?('operating_system'))
          os_string = (ohai_hash['hostnamectl']['operating_system']).to_s
        elsif (ohai_hash.key?('hardware') && ohai_hash['hardware'].key?('operating_system'))
          os_string = "#{ohai_hash['hardware']['operating_system']} #{ohai_hash['hardware']['operating_system_version']}"
        else
          os_string = "#{ohai_hash['platform']} #{ohai_hash['platform_version']}"
        end
        return os_string
      end

      def self.parse_memory(memory_hash)
        total = convert_memory_to_mb(memory_hash['total'])
        if (memory_hash.key?('available'))
          free = convert_memory_to_mb(memory_hash['available'])
        else
          free = convert_memory_to_mb(memory_hash['free'])
        end
        new_memory_hash = { free: free, total: total }
        return new_memory_hash
      end

      def self.parse_kernel(kernel_hash)
        name = 'unknown'
        release = 'unknown'
        machine = 'unknown'
        if (kernel_hash.key?('name'))
          name = kernel_hash['name']
        end
        if (kernel_hash.key?('release'))
          release = kernel_hash['release']
        end
        if (kernel_hash.key?('machine'))
          machine = kernel_hash['machine']
        end
        new_kernel_hash = { name: name, release: release, machine: machine }
        return new_kernel_hash
      end
    end
  end
end
