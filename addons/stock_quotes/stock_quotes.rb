require 'axial/addon'
require 'axial/api/iextrading/v1_0/stock/batch'
require 'axial/api/crypto_compare/data'

module Axial
  module Addons
    class StockQuotes < Axial::Addon
      def initialize(bot)
        super

        @name                           = 'stock market/crypto quotes'
        @author                         = 'sylence <sylence@sylence.org>'
        @version                        = '1.1.0'

        @quote_limit                    = 5

        on_channel           'crypto',  :crypto_quote
        on_channel      'quote|stock',  :stock_quote
        on_channel   'market|markets',  :market_quote

        throttle                        5
      end

      def get_symbol_name(symbol)
        case symbol
          when 'BTC'
            return 'Bitcoin (BTC)'
          when 'XRP'
            return 'Ripple (XRP)'
          when 'LTC'
            return 'Litecoin (LTC)'
          when 'ETH'
            return 'Etherium (ETH)'
          when 'BCH'
            return 'Bitcoin Cash (BCH)'
          when 'DIA'
            return 'Dow Jones ETF (DIA)'
          when 'SPY'
            return 'S&P 500 ETF (SPY)'
          when 'QQQ'
            return 'NASDAQ ETF (QQQ)'
          when 'IWM'
            return 'Russell 2K ETF (IWM)'
        end
      end

      def render_market_quote(channel, nick, type_string, results, batch = false) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        if (batch)
          symbol_length           = results.collect { |result| get_symbol_name(result.symbol).length }.max
        else
          symbol_length           = results.collect { |result| result.symbol.length }.max
          company_symbol_length   = results.collect { |result| "#{result.company_name} (#{result.symbol})".length }.max
        end
        change_length             = results.collect { |result| colorify_result(result)[1].length }.max
        latest_price_length       = results.collect { |result| (format('%.2f', result.latest_price.to_f.round(2).to_s)).to_s.length }.max
        low_length                = results.collect { |result| (format('%.2f', result.low.to_f.round(2).to_s)).to_s.length }.max
        high_length               = results.collect { |result| (format('%.2f', result.high.to_f.round(2).to_s)).to_s.length }.max
        type_string_length        = type_string.length

        if (results.any?)
          results.each do |result|
            channel.message(get_result_string(result))
            type_string       = "#{Colors.blue}#{type_string.center(type_string_length)}#{Colors.reset}"
            quote_color, change = colorify_result(result)
            if (batch)
              symbol          = "#{Colors.cyan}#{get_symbol_name(result.symbol).ljust(symbol_length)}#{Colors.reset}"
            else
              company_symbol  = "#{result.company_name} (#{result.symbol})"
              symbol          = "#{Colors.cyan}#{company_symbol.ljust(company_symbol_length)}#{Colors.reset}"
            end

            latest_price    = "$ #{format('%.2f', result.latest_price.to_f.round(2).to_s).rjust(latest_price_length)}"
            low             = "$ #{format('%.2f',          result.low.to_f.round(2).to_s).rjust(low_length)}"
            high            = "$ #{format('%.2f',         result.high.to_f.round(2).to_s).rjust(high_length)}"

            msg  = "#{Colors.gray}[ #{type_string} #{Colors.gray}]#{Colors.reset} "
            msg += symbol.center(symbol_length)
            msg += " #{Colors.gray}|#{quote_color} "
            msg += latest_price
            msg += " #{Colors.gray}|#{quote_color} "
            msg += change.rjust(change_length)
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += "low: #{low}"
            msg += " #{Colors.gray}|#{Colors.reset} "
            msg += "high: #{high}"
            channel.message(msg)
          end
        else
          channel.message("#{nick.name}: couldn't find any matches for symbols: #{symbols.join(', ')}")
        end
      end

      def market_quote(channel, nick, _command)
        symbols               = %w[DIA SPY QQQ IWM]
        LOGGER.debug("market quote request from #{nick.uhost}: #{symbols.join(', ')}")
        results = API::IEXTrading::V10::Stock::Market.batch(symbols)
        render_market_quote(channel, nick, 'market quote', results, true)
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def crypto_quote(channel, nick, command)
        symbols = %w[BTC ETH XRP BCH LTC]
        LOGGER.debug("crypto quote request from #{nick.uhost}: #{symbols.join(', ')}")
        results = API::CryptoCompare::Data.price_multi_full(symbols)
        render_market_quote(channel, nick, 'crypto quote', results, true)
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def get_percent_string(change_value, total_value)
        float_string = format('%.2f', (change_value.to_f.abs / total_value.to_f.abs).to_f * 100.0) + '%'
        return float_string
      end

      def colorify_result(result)
        change_pct = get_percent_string(result.change, result.latest_price)
        if (result.change.negative?)
          quote_color   = Colors.red
          change_character = "\u2193 "
        elsif (result.change.zero?)
          change_character = ''
          quote_color   = Colors.reset
        else
          quote_color   = Colors.green
          change_character = "\u2191 "
        end
        change_string = "#{change_character}#{format('%.2f', result.change.to_f.round(2).to_s).gsub(/^-/, '')} (#{change_pct})"
        # do what with quote_color?
        return [quote_color, change_string]
      end

      def stock_quote(channel, nick, command) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        symbols = command.args.gsub(/\s+/, ',').split(',').collect(&:strip).select { |symbol| !symbol.nil? && !symbol.empty? }
        if (symbols.empty?)
          channel.message("#{nick.name}: usage: #{command.command} <symbols>")
          throttle(2)
          return
        end

        symbols = (symbols.count > @quote_limit) ? symbols[0..4] : symbols

        throttle(symbols.count * 2)
        LOGGER.debug("stock quote request from #{nick.uhost}: #{symbols.join(', ')}")
        results = API::IEXTrading::V10::Stock::Market.batch(symbols)
        if (results.any?)
          render_market_quote(channel, nick, 'ticker', results)
        else
          channel.message("#{nick.name}: couldn't find any matches for symbols: #{symbols.join(', ')}")
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
