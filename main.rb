
require 'binance'
require 'parallel'
require 'time'
require 'truncate'
MIN_PROFIT = 0.1
TRADING = false
RESULTING_CURRENCY = 'GBP'
RESULTING_CURRENCY_REGEX = /GBP$/
# BLACKLIST = ["SHIBBTC","BTCSHIB","SHIBGBP","WBTCETH",'SSVETH',"CRVETH"]
BLACKLIST = []
# total stake for the resulting currency - ensure this is a float like 20.00
TOTAL_STAKE = 25.00
SPOT_FEE = 0.075


# put your api key and secret in these Environmental variables on your system
binance = Binance::Client::REST.new(api_key:ENV['binance-scout-key'],secret_key:ENV['binance-scout-secret'])

EXCHANGE_INFO = binance.exchange_info
# puts EXCHANGE_INFO["symbols"]
sleep 10

def btc_fee_free
  result = EXCHANGE_INFO["symbols"].select(){|symbol| symbol["symbol"]["quoteAsset"] == "BTC"}
  result = result.map do |result|
    result["symbol"]
  end
  return result
end

FEE_FREE_SYMBOLS = btc_fee_free

def get_quote_asset_precision(symbol_to_find,exchange_info=EXCHANGE_INFO)
  result = exchange_info["symbols"].select(){|symbol| symbol["symbol"] == "#{symbol_to_find}"}
  # puts "quote asset precision is #{result}"
  result[0]["quoteAssetPrecision"]
end
def get_base_asset_precision(symbol_to_find,exchange_info=EXCHANGE_INFO)
  result = exchange_info["symbols"].select(){|symbol| symbol["symbol"] == "#{symbol_to_find}"}
  # puts "base asset precision is #{result}"
  result[0]["baseAssetPrecision"]
end
def get_quote_asset_precision(symbol_to_find,exchange_info=EXCHANGE_INFO)
  result = exchange_info["symbols"].select(){|symbol| symbol["symbol"] == "#{symbol_to_find}"}
  # puts "quote asset precision is #{result}"
  result[0]["quoteAssetPrecision"]
end

def get_buy_commision_precision(symbol_to_find,exchange_info=EXCHANGE_INFO)
  result = exchange_info["symbols"].select(){|symbol| symbol["symbol"] == "#{symbol_to_find}"}
  # puts "quote asset precision is #{result}"
  result[0]["baseCommissionPrecision"].to_i
end

def get_sell_commision_precision(symbol_to_find,exchange_info=EXCHANGE_INFO)
  result = exchange_info["symbols"].select(){|symbol| symbol["symbol"] == "#{symbol_to_find}"}
  # puts "quote asset precision is #{result}"
  result[0]["quoteCommissionPrecision"].to_i
end
def get_base_asset_precision(symbol_to_find,exchange_info=EXCHANGE_INFO)
  result = exchange_info["symbols"].select(){|symbol| symbol["symbol"] == "#{symbol_to_find}"}
  puts "base asset precision is #{result}"
  result[0]["baseAssetPrecision"]
end
def resulting_currency_pairs
  Parallel.map(resulting_currency_orders,in_threads:resulting_currency_orders.length) do |pair|
    pair['symbol']
  end
end

def remove_resulting_currency(order)
  order['symbol'].delete_suffix(RESULTING_CURRENCY)
end



def get_matching_pairs(trade, order_set, resulting_currency_pairs)
  resulting_currency_pairs.map do |pair|
    check = Regexp.new("^#{pair}").match? trade['symbol']
    check2 = Regexp.new("#{pair}$").match? trade['symbol']
    if check || check2
      order_set.select{|order| order['symbol'] == "#{pair}#{RESULTING_CURRENCY}"}
    end
  end
end


# trade3_set = resulting_currency_orders
def negate_fee(trade,tariff=SPOT_FEE)
  amount = trade["askPrice"].to_f
  rate = FEE_FREE_SYMBOLS.include?(trade["symbol"]) ? 0.0 : tariff
  return amount - (amount * rate.to_f)
end
def calculate_result(trade1, trade2, trade3)
  product = negate_fee(trade1).round(get_buy_commision_precision(trade1["symbol"])) * negate_fee(trade2).round(get_sell_commision_precision(trade2["symbol"])) * negate_fee(trade3).round(get_sell_commision_precision(trade3["symbol"]))
  product = product / trade1['askPrice'].to_f
  product - trade1['askPrice'].to_f
end

def find_quote_asset_coin(pair)
  quote_asset = EXCHANGE_INFO["symbols"].select(){|canditate| canditate["symbol"] == pair}
  quote_asset[0]["quoteAsset"]
  end
def find_base_asset_coin(pair)
  quote_asset = EXCHANGE_INFO["symbols"].select(){|canditate| canditate["symbol"] == pair}
  quote_asset[0]["baseAsset"]
end

def find_balance_for_trade_two(account_information,pair)
  base_asset = find_base_asset_coin pair
  coin = account_information["balances"].select(){|asset| asset["asset"] == base_asset}
  puts "trade 2 balance is #{coin}"
  return coin[0]["free"].to_f
end

def find_balance(account_information,pair)
  coin = account_information["balances"].select(){|asset| asset["asset"] == pair.delete_suffix(RESULTING_CURRENCY)}
  return coin[0]["free"].to_f
end

def guilotine_float(float, desired_precision)
  # truncates float to desired precision
  float.truncate desired_precision
end

def get_lot_size_for_product(symbol_to_find,exchange_info=EXCHANGE_INFO)
  result = exchange_info["symbols"].select(){|symbol| symbol["symbol"] == "#{symbol_to_find}"}
  puts "lot size step size is #{result[0]["filters"][1]["stepSize"]}"
  result[0]["filters"][1]["stepSize"]
end

def get_rounding_position(step_size)
  if step_size >= 1
    # 1.0
    # 0 + -1 = -1 = correct!
    sig_fig = "#{"%f" % step_size}".index('1') + "#{"%f" % step_size}".index('.')
    puts "sig_fig for #{step_size}  is #{sig_fig}"
    return sig_fig
  elsif step_size < 1
    # 0.001
    # 4 - 1 = 3 = correct!
    sig_fig = "#{"%f" % step_size}".index('1') - "#{"%f" % step_size}".index('.')
    puts "sig_fig for #{step_size}  is #{sig_fig}"
    return sig_fig
  end
end

def calculate_quantity(raw_amount,symbol)
  step_size = get_lot_size_for_product(symbol,EXCHANGE_INFO).to_f
  puts "calculate_quantity step size is #{step_size}"
  result = raw_amount.truncate(get_rounding_position(step_size))
  puts "quantity is #{result}"
  return result.to_s
end

def get_tick_size_for_product(symbol_to_find,exchange_info=EXCHANGE_INFO)
  result = exchange_info["symbols"].select(){|symbol| symbol["symbol"] == "#{symbol_to_find}"}
  puts result[0]["filters"][0]["tickSize"]
  result[0]["filters"][0]["tickSize"]
end

def calculate_price(raw_amount,symbol)
  step_size = get_tick_size_for_product(symbol,EXCHANGE_INFO).to_f
  result = raw_amount.round(get_rounding_position(step_size))
  puts "price is: #{result}"
  return result.to_s
end



def get_wallet_balance(coin,binance)
  balance = binance.account_info["balances"].select(){|balance| balance["asset"] == coin}
  balance[0]["free"].to_f
end

def wait_until_filled(order,to_execute_trade_number,binance)
  filled = order["status"]
  while filled != "FILLED"
    order_query = binance.query_order(symbol: to_execute_trade_number,orderId: order["orderId"])
    filled = order_query["status"]
    puts order_query
    puts filled
    sleep 2.5
  end
end

while true
  order_book = binance.book_ticker.delete_if(){|pair| BLACKLIST.include?(pair["symbol"])}
  resulting_currency_orders = order_book.select(){|order| order['symbol'].match? RESULTING_CURRENCY_REGEX}
  resulting_currency_pairs_result = Parallel.map(resulting_currency_orders, in_threads:resulting_currency_orders.length) do |order|
    # remove resulting currency from orders
    remove_resulting_currency(order)
  end

  # trade1_set = resulting_currency_orders

  trade2_set = Parallel.map(resulting_currency_orders,in_threads:resulting_currency_orders.length) do |order|
    # trade1 is order
    search = remove_resulting_currency(order)
    {order => order_book.select(){|trade| trade['symbol'].match(/^#{search}/) }}
  end


  # trade3_set = resulting_currency_orders
  results = Parallel.map(trade2_set,in_threads:trade2_set.length) do |trade|
    trade.values.map do |trade2set|
      trade2set.map do |trade2|
        begin
          trade_one_and_three = get_matching_pairs(trade2, resulting_currency_orders, resulting_currency_pairs_result).compact
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


  # amount to process has to be a string - ensures decimal places without round.
  # expect lots of dust
  results = results.flatten(4).compact.select(){|chain| chain[:result].is_a?(Float) && !chain[:result].nan? }
  results = results.sort_by(){|result| result[:result]}
  results = results.uniq
  # result is the profit from resulting currency in, displayed in resulting currency out
  to_execute = results[-1]
  print to_execute
  print "\n"
  if TRADING
    if to_execute[:result] >= MIN_PROFIT
      order1 = binance.create_order!({ symbol: to_execute[:trade1], side: 'BUY', type:'LIMIT', quantity: "#{calculate_quantity(TOTAL_STAKE / to_execute[:ask1].to_f,to_execute[:trade1])}", price: calculate_price(to_execute[:ask1].to_f,to_execute[:trade1]), timeInForce: "GTC"})
      puts order1
      unless order1["status"]  == 'FILLED'
        wait_until_filled(order1,to_execute[:trade1], binance)
      end
      # sleep 1
      # order2 = binance.create_order!({symbol: to_execute[:trade2],side: 'SELL',type:'LIMIT',quantity: "#{calculate_quantity((TOTAL_STAKE / to_execute[:ask1].to_f) * to_execute[:ask2].to_f,to_execute[:trade2])}",price: calculate_price(to_execute[:ask2].to_f,to_execute[:trade2]),timeInForce: "GTC"})
      order2 = binance.create_order!({symbol: to_execute[:trade2],side: 'SELL',type:'LIMIT',quantity: "#{calculate_quantity(find_balance_for_trade_two(binance.account_info({"recvWindow":"10000"}),to_execute[:trade2]),to_execute[:trade2])}",price: calculate_price(to_execute[:ask2].to_f,to_execute[:trade2]),timeInForce: "GTC"})
      puts order2
      unless order2["status"]  == 'FILLED'
        wait_until_filled(order2,to_execute[:trade2], binance)
      end
      # account_information = binance.account_info({recvWindow:10000})
      # balance = find_balance(account_information,to_execute[:trade3])
      # dust = binance.price(symbol:to_execute[:trade3])["price"].to_f % balance.to_f
      # balance = balance.to_f - dust
      # puts balance
      # puts account_information
      # next_quantity = order2["cummulativeQuoteQty"].to_f * 0.999
      # next_quantity = next_quantity.round(5) - 0.00001
      # puts next_quantity
      # sleep 1
      # order3 = binance.create_order!({symbol: to_execute[:trade3],side: 'SELL',type:'LIMIT',quantity: "#{calculate_quantity(((TOTAL_STAKE / to_execute[:ask1].to_f) * to_execute[:ask2].to_f) * to_execute[:ask3].to_f,to_execute[:trade3])}",price: calculate_price(to_execute[:ask3].to_f,to_execute[:trade3]),timeInForce: "GTC"})
      # order3 = binance.create_order!({symbol: to_execute[:trade3],side: 'SELL',type:'MARKET',quantity: "#{calculate_quantity(((TOTAL_STAKE / to_execute[:ask1].to_f) * to_execute[:ask2].to_f) * to_execute[:ask3].to_f,to_execute[:trade3])}",price: to_execute[:ask3],timeInForce: "GTC"})
      order3 = binance.create_order!({symbol: to_execute[:trade3],side: 'SELL',type:'LIMIT',quantity: "#{calculate_quantity(find_balance_for_trade_two(binance.account_info({"recvWindow":"10000"}),to_execute[:trade3]).to_f,to_execute[:trade3])}",price: calculate_price(to_execute[:ask3].to_f,to_execute[:trade3]),timeInForce: "GTC"})
      puts order3
      unless order3["status"] == 'FILLED'
        wait_until_filled(order3,to_execute[:trade3],binance)
      end
    end
    sleep 2
  end
end