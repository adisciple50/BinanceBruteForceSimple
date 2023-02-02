# prerequisites

ruby 3.1.2 or higher

binance api key and api secret

bundler

# installation instructions

set these environmental variables
'BINANCE_SCOUT_KEY'
'BINANCE_SCOUT_SECRET'

bundle install

in the directory where the Gemfile is. default is project root.

# configuration

set MIN_PROFIT to the decimal you like to set the minimum profit threshold per trade - lower thresholds tend to appear more often. default is pounds. example 1.00 for one pound. or 0.10 for 10 pence. this is on line 6 of main.rb. default is 0.10 (10 pence)

set whether you want just the results or you want to trade when the result reaches the MIN_PROFIT threshold. do this buy setting the ruby boolean value as true or false (false for not making trades just scouting). this is on line 7 of main.rb. 

set the binance spot fee percentage (their commission) as SPOT_FEE, where 100% is 1.0 and 10 percent is 0.1 and the default if your paying by BNB coin (presently) is 0.075 which is 7.5 percent.

set the RESULTING_CURRENCY and RESULTING_CURRENCY_REGEX. do this by replacing the binance currency code (shown in your wallet) where GBP is. WARNING THIS IS CASE SENSITIVE AND SHOULD BE ALL CAPS. for example to change it to USD change the constant values to USD ignoring the surrounding characters/quotation marks/forward slashes and the dollar sign (leave these in place). do this on line 8 and 9. default is GBP so leave this if want to trade and or have the results in british pounds. 

set your total amount of resulting currency to invest (the start currency is the same as the end currency) in each trade. this is set on the TOTAL_STAKE constant on line 13 of main.rb. default is  GBP (Great British Pounds). The Currency is Set By the RESULTING_CURRENCY constant.

(optional)

set any blacklisted symbols you want, ["ETHBTC","ETHBNB"], for example on line 11 following the example on line 10.
WARNING, THIS IS CASE SENSITIVE, AND SHOULD BE ALL CAPS UNLESS YOU KNOW OTHERWISE.

set 

TRADING = false 

to see if your settings work, then run:

bundle exec ruby main.rb

then set TRADING = true

then

bundle exec ruby main.rb

again to trade on autopilot for a preset profit or better!