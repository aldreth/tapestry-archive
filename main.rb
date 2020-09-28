require 'dotenv/load'
require 'httparty'
require 'mini_exiftool_vendored'
require 'nokogiri'


cookie_name = 'tapestry_session'
cookie_value = ENV['COOKIE_VALUE']


options = { 'headers': { 'Cookie': "#{cookie_name}=#{cookie_value}" }}

url = 'https://tapestryjournal.com/s/scarcroft-green-nursery/observation/14192'

raw = HTTParty.get(url, options)

doc = Nokogiri::HTML(raw)

image_url = doc.css('.obs-media-gallery-main img').attribute('src').value

image = HTTParty.get(image_url)



title = doc.css('h1').first.text.strip
image_description = doc.css('.page-note p').text.strip

file_name = title.downcase.gsub(' ', '-') + '.jpeg'

File.write(file_name, image)

photo =  MiniExiftool.new(file_name)
photo.title = title
photo.image_description = image_description
photo.save
