# frozen_string_literal: true

require 'dotenv/load'
require 'httparty'
require 'mini_exiftool_vendored'
require 'nokogiri'

BASE_URL = 'https://tapestryjournal.com/s/scarcroft-green-nursery/observation'

def get_doc(observation_id)
  cookie_name = 'tapestry_session'
  cookie_value = ENV['COOKIE_VALUE']
  options = { 'headers': { 'Cookie': "#{cookie_name}=#{cookie_value}" } }
  url = "#{BASE_URL}/#{observation_id}"
  raw = HTTParty.get(url, options)
  Nokogiri::HTML(raw)
end

def get_file_name(metadata:, index:, video: false)
  file_name = './images/'
  file_name += metadata[:title].downcase.gsub(' ', '-')
  file_name += "-#{index}" if index.positive?
  file_name += video ? '.mp4' : '.jpeg'
  file_name
end

def get_metadata(doc)
  title = doc.css('h1').first.text.strip
  description = doc.css('.page-note p').text.strip.gsub(/\s+/, ' ')
  doc.css('.obs-metadata p').first.text.strip.match(/Authored by (.*) added (.*)/)
  author = Regexp.last_match(1)
  date = Date.parse(Regexp.last_match(2))
  { title: title, description: description, author: author, date: date }
end

def save_images_for_page(images:, metadata:)
  images.each_with_index do |img, idx|
    image_url = img.attribute('src').value
    image = HTTParty.get(image_url)

    file_name = get_file_name(metadata: metadata, index: idx)
    File.write(file_name, image)

    photo = MiniExiftool.new(file_name)
    photo.title = metadata[:title]
    photo.image_description = metadata[:description]
    photo.save
  end
end

def save_videos_for_page(videos:, metadata:)
  videos.each_with_index do |img, idx|
    video_url = img.attribute('src').value
    video = HTTParty.get(video_url)

    file_name = get_file_name(metadata: metadata, index: idx, video: true)
    File.write(file_name, video)

    # photo =  MiniExiftool.new(file_name)
    # photo.title = title
    # photo.image_description = image_description
    # photo.save
  end
end

def save_media_for_page(doc)
  images = doc.css('.obs-media-gallery-main img')
  videos = doc.css('.obs-media-gallery-main .obs-video-wrapper video source')
  metadata = get_metadata(doc)

  save_images_for_page(images: images, metadata: metadata)
  save_videos_for_page(videos: videos, metadata: metadata)
end

def get_next_observation_id(doc)
  next_link = doc.css('li.next a')
  return nil if next_link.nil? || next_link.empty?

  next_link.attribute('href')
           .value
           .match(%r{#{Regexp.quote(BASE_URL)}/(\d*)})
           .captures
           .first
end

observation_id = ENV['FIRST_OBSERVATION_ID']

while observation_id
  puts observation_id
  doc = get_doc(observation_id)
  save_media_for_page(doc)
  observation_id = get_next_observation_id(doc)
end
