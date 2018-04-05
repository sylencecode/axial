require 'axial/addon'
require 'axial/api/iextrading/v1_0/stock/batch'

module Axial
  module Addons
    class StockQuotes < Axial::Addon

      def initialize(bot)
        super

        @name    = 'stock market quotes'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        on_channel    'quote|stock',  :stock_quote
        on_channel 'market|markets',  :market_quote

        throttle                      5
      end

      def market_quote(channel, nick, command)
        # dow, s&p, nasdaq, russell 2000
      end

      def crypto_quote(channel, nick, command)

      end

      def stock_quote(channel, nick, command)
        symbols = command.args.split(',').collect { |symbol| symbol.strip }.select{ |symbol| !symbol.nil? && !symbol.empty? }
        if (symbols.empty?)
          # market quote
        elsif (symbols.count > 3)
          channel.message("#{nick.name}: only 3 symbols at a time, please.")
        else
          LOGGER.debug("stock quote request from #{nick.uhost}: #{symbols.join(', ')}")
          results = Axial::API::IEXTrading::V10::Stock::Market.batch(symbols)
          if (results.any?)
            results.each do |symbol, result|
              change_pct = format("%.2f", (result.change.to_f.abs / result.latest_price.to_f.abs).to_f * 100.0) + '%'

              if (result.change < 0)
                quote_color = Colors.red
                change_string = "\u2193 " + format("%.2f", result.change.to_f.round(2).to_s).gsub(/^-/, '') + " (#{change_pct})"
              elsif (result.change == 0)
                quote_color = Colors.reset
                change_string = format("%.2f", result.change.to_f.round(2).to_s) + " (#{change_pct})"
              else
                quote_color = Colors.green
                change_string = "\u2191 " + format("%.2f", result.change.to_f.round(2).to_s) + " (#{change_pct})"
              end

              msg =  "#{Colors.gray}[#{Colors.blue} #{result.company_name} #{Colors.gray}]#{Colors.reset} "
              msg += "#{quote_color}#{symbol}#{Colors.reset}"
              msg += " #{Colors.gray}|#{quote_color} "
              msg += "$#{format("%.2f", result.latest_price.to_f.round(2).to_s)} "
              msg += "#{Colors.gray}|#{quote_color} "
              msg += "#{change_string}"
              msg += " #{Colors.gray}|#{Colors.reset} "
              msg += "low: $#{format("%.2f", result.low.to_f.round(2).to_s)}"
              msg += " #{Colors.gray}|#{Colors.reset} "
              msg += "high: $#{format("%.2f", result.high.to_f.round(2).to_s)}"
              msg += " #{Colors.gray}|#{Colors.reset} "
              msg += "news: #{result.news[:headline]}"
              channel.message(msg)
            end
          else
            channel.message("#{nick.name}: couldn't find any matches for symbols: #{symbols.join(', ')}")
          end
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def before_reload()
        super
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end
