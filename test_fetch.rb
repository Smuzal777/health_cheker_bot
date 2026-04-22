require 'faraday'
require 'faraday/follow_redirects'; require 'nokogiri'
h = {'User-Agent' => 'Mozilla/5.0'}
puts Faraday.new{|f|f.response :follow_redirects}.get('https://elibrary.ru/item.asp?id=54313730', nil, h).body
