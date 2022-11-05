require 'binance'
require 'parallel'
require 'time'

RESULTING_CURRENCY = 'GBP'
RESULTING_CURRENCY_REGEX = /GBP$/
# BLACKLIST = ["SHIBBTC","BTCSHIB","SHIBGBP","WBTCETH",'SSVETH',"CRVETH"]
BLACKLIST = []
# total stake for the resulting currency - ensure this is a float like 20.00
TOTAL_STAKE = 20.00

# put your api key and secret in these Environmental variables on your system
binance = Binance::Client::REST.new(api_key:ENV['binance-scout-key'],secret_key:ENV['binance-scout-secret'])

while true
  order_book = binance.book_ticker.delete_if(){|pair| BLACKLIST.include?(pair["symbol"])}
  resulting_currency_orders = order_book.select(){|order| order['symbol'].match? RESULTING_CURRENCY_REGEX}

  def resulting_currency_pairs
    Parallel.map(resulting_currency_orders,in_threads:resulting_currency_orders.length) do |pair|
      pair['symbol']
    end
  end

  def remove_resulting_currency(order)
    order['symbol'].delete_suffix(RESULTING_CURRENCY)
  end

  resulting_currency_pairs_result = Parallel.map(resulting_currency_orders, in_threads:resulting_currency_orders.length) do |order|
    # remove resulting currency from orders
    remove_resulting_currency order
  end

  # trade1_set = resulting_currency_orders

  trade2_set = Parallel.map(resulting_currency_orders,in_threads:resulting_currency_orders.length) do |order|
    # trade1 is order
    search = remove_resulting_currency(order)
    {order => order_book.select(){|trade| trade['symbol'].match(/^#{search}/) }}
  end

  def get_matching(trade,order_set,resulting_currency_pairs)
    resulting_currency_pairs.map do |pair|
      check = Regexp.new("^#{pair}").match? trade['symbol']
      check2 = Regexp.new("#{pair}$").match? trade['symbol']
      if check || check2
        order_set.select{|order| order['symbol'] == "#{pair}#{RESULTING_CURRENCY}"}
      end
    end
  end

  # trade3_set = resulting_currency_orders

  def calculate_result(trade1, trade2, trade3)
    product = trade1['askPrice'].to_f * trade2['askPrice'].to_f * trade3['askPrice'].to_f
    product = product / trade1['askPrice'].to_f
    product - trade1['askPrice'].to_f
  end

  results = Parallel.map(trade2_set,in_threads:trade2_set.length) do |trade|
      trade.values.map do |trade2set|
        trade2set.map do |trade2|
          begin
          trade_one_and_three = get_matching(trade2, resulting_currency_orders, resulting_currency_pairs_result).compact
          trade1 = trade_one_and_three[1][0]
          trade3 = trade_one_and_three[0][0]

          [{:trade1 => trade1['symbol'],:trade2 => trade2['symbol'],:trade3 => trade3['symbol'],:ask1 => trade1['askPrice'],:ask2 => trade2['askPrice'],:ask3 => trade3['askPrice'],:result => calculate_result(trade1, trade2, trade3) },
           {:trade1 => trade3['symbol'],:trade2 => trade2['symbol'],:trade3 => trade1['symbol'],:ask1 => trade3['askPrice'],:ask2 => trade2['askPrice'],:ask3 => trade1['askPrice'],:result => calculate_result(trade3, trade2, trade1) }
          ]
          rescue
            nil
          end
        end
      end
    end

  results = results.flatten(4).compact.select(){|chain| chain[:result].is_a?(Float) && !chain[:result].nan? }
  results = results.sort_by(){|result| result[:result]}
  results = results.uniq
  # result is the profit from resulting currency in, displayed in resulting currency out
  puts results[-1]
  if results[-1][:result] > 0.009
    order1 = binance.create_order!({symbol: results[-1][:trade1],side: 'BUY',type:'MARKET',quoteOrderQty: TOTAL_STAKE})
    order2 = binance.create_order!({symbol: results[-1][:trade2],side: 'BUY',type:'MARKET',quoteOrderQty: order1["executedQty"].to_f})
    order3 = binance.create_order!({symbol: results[-1][:trade3],side: 'BUY',type:'MARKET',quoteOrderQty: order2["executedQty"].to_f})
  end
  puts order1
  puts order2
  puts order3
  sleep 1
end