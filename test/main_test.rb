require 'binance'
require 'minitest/autorun'
require 'minitest'
require_relative '../main'
class MainTest < Minitest::Test
  include BinanceBruteForceTrader
  def setup
    @binance = Binance::Client::REST.new(api_key:ENV['binance-scout-key'],secret_key:ENV['binance-scout-secret'])
    @exchange_info = binance.exchange_info
  end

  def teardown
    # Do nothing
  end

  def test_get_base_asset_precision
    precision_to_get = get_base_asset_precision('BTCGBP',@exchange_info)
    assert_kind_of Integer,precision_to_get,"precision retrieved isnt an int"
    assert precision_to_get > 0
  end
end