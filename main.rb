require 'dotenv/load'
require 'httparty'
require 'mini_exiftool_vendored'
require 'nokogiri'

def getImagesForPage(observation_id)
  image_dir = './images/'

  cookie_name = 'tapestry_session'
  cookie_value = ENV['COOKIE_VALUE']

  options = { 'headers': { 'Cookie': "#{cookie_name}=#{cookie_value}" }}

  base_url = 'https://tapestryjournal.com/s/scarcroft-green-nursery/observation'

  url = "#{base_url}/#{observation_id}"

  raw = HTTParty.get(url, options)

  doc = Nokogiri::HTML(raw)

  images = doc.css('.obs-media-gallery-main img')

  title = doc.css('h1').first.text.strip
  image_description = doc.css('.page-note p').text.strip

  images.each_with_index do |img, idx|
    image_url = img.attribute('src').value
    image = HTTParty.get(image_url)

    file_name = image_dir
    file_name += title.downcase.gsub(' ', '-')
    file_name += "-#{idx}" if idx > 0
    file_name += '.jpeg'

    File.write(file_name, image)

    photo =  MiniExiftool.new(file_name)
    photo.title = title
    photo.image_description = image_description
    photo.save
  end
end

observation_id = '13980'

getImagesForPage(observation_id)
