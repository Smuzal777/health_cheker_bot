require 'nokogiri'
doc = Nokogiri::HTML(File.read('elibrary_dump.html', encoding: 'UTF-8'))
puts doc.text[0..500]