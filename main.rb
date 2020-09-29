# frozen_string_literal: true

require 'dotenv/load'
require 'httparty'
require 'mini_exiftool_vendored'
require 'nokogiri'

def get_doc(observation_id)
  image_dir = './images/'

  cookie_name = 'tapestry_session'
  cookie_value = ENV['COOKIE_VALUE']

  options = { 'headers': { 'Cookie': "#{cookie_name}=#{cookie_value}" } }

  base_url = 'https://tapestryjournal.com/s/scarcroft-green-nursery/observation'

  url = "#{base_url}/#{observation_id}"

  raw = HTTParty.get(url, options)

  Nokogiri::HTML(raw)
end

def get_file_name(title:, index:, video: false)
  file_name = './images/'
  file_name += title.downcase.gsub(' ', '-')
  file_name += "-#{index}" if index.positive?
  file_name += video ? '.mp4' : '.jpeg'
  file_name
end

def get_images_for_page(doc)
  images = doc.css('.obs-media-gallery-main img')
  videos = doc.css('.obs-media-gallery-main .obs-video-wrapper video source')

  title = doc.css('h1').first.text.strip
  image_description = doc.css('.page-note p').text.strip.gsub(/\s+/, ' ')

  images.each_with_index do |img, idx|
    image_url = img.attribute('src').value
    image = HTTParty.get(image_url)

    file_name = get_file_name(title: title, index: idx)
    File.write(file_name, image)

    photo = MiniExiftool.new(file_name)
    photo.title = title
    photo.image_description = image_description
    photo.save
  end

  videos.each_with_index do |img, idx|
    video_url = img.attribute('src').value
    video = HTTParty.get(video_url)

    file_name = get_file_name(title: title, index: idx, video: true)
    File.write(file_name, video)

    # photo =  MiniExiftool.new(file_name)
    # photo.title = title
    # photo.image_description = image_description
    # photo.save
  end
end

def get_next_observation_id(doc)
  next_link = doc.css('li.next a')
  return nil if next_link.nil? || next_link.empty?

  next_link.attribute('href')
           .value
           .match(/https:\/\/tapestryjournal.com\/s\/scarcroft-green-nursery\/observation\/(\d*)/)[1]
end

observation_id = ENV['FIRST_OBSERVATION_ID']

while observation_id do
  puts observation_id
  doc = get_doc(observation_id)
  get_images_for_page(doc)
  observation_id = get_next_observation_id(doc)
end
