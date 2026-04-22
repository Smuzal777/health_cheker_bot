require 'faraday'
require 'faraday/follow_redirects'
require 'nokogiri'
html = Faraday.new { |f| f.response :follow_redirects }.get('https://api.allorigins.win/raw?url=https://elibrary.ru/item.asp?id=45781198').body;
puts html[0..500]
