#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dotenv/load'
require 'httparty'
require 'mini_exiftool_vendored'
require 'nokogiri'
require 'nokogumbo'
require 'fileutils'

def get_doc(observation_id)
  cookie_name = 'tapestry_session'
  cookie_value = ENV['COOKIE_VALUE']
  options = { 'headers': { 'Cookie': "#{cookie_name}=#{cookie_value}" } }
  url = "#{BASE_URL}/#{observation_id}"
  response = HTTParty.get(url, options)
  Nokogiri.HTML5(response.body)
end

def get_file_name(output_path:, metadata:, index:, video: false)
  file_name = metadata[:date].strftime("#{output_path}/%Y-%m-%d-%H-%M-")
  file_name += metadata[:title]
               .downcase
               .delete("^\u{0000}-\u{007F}")
               .strip
               .squeeze
               .gsub(' ', '-')
  file_name += "-#{index}" if index.positive?
  file_name += video ? '.mp4' : '.jpeg'
  file_name
end

def markdown_description(raw)
  # remove leading and trailing from every line, then use markdown hard wrap (trailing double space) to retain layout
  raw.strip.split("\n").map{|l|l.strip}.join("  \n")
end

def get_metadata(doc)
  title = doc.css('h1').first.text.strip
  description = markdown_description(doc.css('.page-note p').text)
  doc.css('.obs-metadata p').first.text.strip.match(/Authored by (.*) added (.*)/)
  artist = Regexp.last_match(1)
  date = DateTime.parse(Regexp.last_match(2))
  { title: title, description: description, artist: artist, date: date }
end

def set_metadata_for_image(file_name:, metadata:)
  photo = MiniExiftool.new(file_name)
  photo.title = metadata[:title]
  photo.image_description = metadata[:description]
  photo.artist = metadata[:artist]
  photo.datetimeoriginal = metadata[:date]
  photo.save
end

def save_images_for_page(output_path:, images:, metadata:)
  images.each_with_index do |img, idx|
    image_url = img.attribute('src').value
    image = HTTParty.get(image_url)

    file_name = get_file_name(output_path: output_path, metadata: metadata, index: idx)
    File.write(file_name, image)
    set_metadata_for_image(file_name: file_name, metadata: metadata)
  end
end

def save_videos_for_page(output_path:, videos:, metadata:)
  videos.each_with_index do |img, idx|
    video_url = img.attribute('src').value
    video = HTTParty.get(video_url)

    file_name = get_file_name(output_path: output_path, metadata: metadata, index: idx, video: true)
    File.write(file_name, video)
  end
end

def capture_observation_info(metadata)
  md = "## #{metadata[:title]}\n\n"
  md += "### #{metadata[:artist]}, #{metadata[:date].strftime('%-d %B %Y %l:%M%P')}\n\n"
  md += "#{metadata[:description]}\n\n"
  md
end

def save_media_for_page(output_path:, doc:)
  images = doc.css('.obs-media-gallery-main img')
  videos = doc.css('.obs-media-gallery-main .obs-video-wrapper video source')
  metadata = get_metadata(doc)
  save_images_for_page(output_path: output_path, images: images, metadata: metadata)
  save_videos_for_page(output_path: output_path, videos: videos, metadata: metadata)
  capture_observation_info(metadata)
end

def get_next_observation_id(doc)
  next_link = doc.css('li.previous a')
  return nil if next_link.nil? || next_link.empty?

  next_link.attribute('href')
           .value
           .match(%r{#{Regexp.quote(BASE_URL)}/(\d*)})
           .captures
           .first
end

BASE_URL = "https://tapestryjournal.com/s/#{ENV['SCHOOL']}/observation"
output_path = File.expand_path(ENV['OUTPUT_PATH'])
FileUtils.mkdir_p(output_path) unless Dir.exist?(output_path)
puts "Saving to #{output_path}"

observation_id_file="#{output_path}/observation_id.txt"
if File.exist?(observation_id_file)
  observation_id = Integer(File.read("#{output_path}/observation_id.txt"))
  puts "Continuing from after last saved observation # #{observation_id}"
  doc = get_doc(observation_id)
  observation_id = get_next_observation_id(doc) # skip last completed entry
else
  observation_id = ENV["FIRST_OBSERVATION_ID"]
  puts "Starting from configured observation: # #{observation_id}"
end

while observation_id
  puts observation_id
  doc = get_doc(observation_id)
  observation_path="#{output_path}/#{observation_id}"
  FileUtils.mkdir_p(observation_path) unless Dir.exist?(observation_path)
  md=save_media_for_page(output_path: observation_path, doc: doc)
  File.write("#{observation_path}/observations-#{observation_id}.txt", md)
  File.write("#{output_path}/observation_id.txt", observation_id)
  observation_id = get_next_observation_id(doc)
end

