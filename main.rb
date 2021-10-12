#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dotenv/load'
require 'httparty'
require 'kramdown'
require 'mini_exiftool_vendored'
require 'nokogiri'
require 'nokogumbo'
require 'pdfkit'
require 'fileutils'

BASE_URL = "https://tapestryjournal.com/s/#{ENV['SCHOOL']}/observation"
output_path = ENV['OUTPUT_PATH']

def get_doc(observation_id)
  cookie_name = 'tapestry_session'
  cookie_value = ENV['COOKIE_VALUE']
  options = { 'headers': { 'Cookie': "#{cookie_name}=#{cookie_value}" } }
  url = "#{BASE_URL}/#{observation_id}"
  response = HTTParty.get(url, options)
  Nokogiri.HTML5(response.body)
end

def get_file_name(metadata:, index:, video: false)
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

def get_metadata(doc)
  title = doc.css('h1').first.text.strip
  description = doc.css('.page-note p').text.strip.gsub(/\s+/, ' ')
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

def save_images_for_page(images:, metadata:)
  images.each_with_index do |img, idx|
    image_url = img.attribute('src').value
    image = HTTParty.get(image_url)

    file_name = get_file_name(metadata: metadata, index: idx)
    if !Dir.exist?(File.dirname(file_name))
      FileUtils.mkdir_p(File.dirname(file_name))
    end
    File.write(file_name, image)
    set_metadata_for_image(file_name: file_name, metadata: metadata)
  end
end

def save_videos_for_page(videos:, metadata:)
  videos.each_with_index do |img, idx|
    video_url = img.attribute('src').value
    video = HTTParty.get(video_url)

    file_name = get_file_name(metadata: metadata, index: idx, video: true)
    if !Dir.exist?(File.dirname(file_name))
      FileUtils.mkdir_p(File.dirname(file_name))
    end
    File.write(file_name, video)
  end
end

def capture_observation_info(metadata)
  md = "## #{metadata[:title]}\n\n"
  md += "### #{metadata[:artist]}, #{metadata[:date].strftime('%-d %B %Y %l:%M%P')}\n\n"
  md += "#{metadata[:description]}\n\n"
  md
end

def save_media_for_page(doc)
  images = doc.css('.obs-media-gallery-main img')
  videos = doc.css('.obs-media-gallery-main .obs-video-wrapper video source')
  metadata = get_metadata(doc)
  save_images_for_page(images: images, metadata: metadata)
  save_videos_for_page(videos: videos, metadata: metadata)
  capture_observation_info(metadata)
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

md =  "# Tapestry observations for #{ENV['NAME']}\n\n"
while observation_id
  puts observation_id
  doc = get_doc(observation_id)
  md += save_media_for_page(doc)
  observation_id = get_next_observation_id(doc)
end

html = Kramdown::Document.new(md).to_html
kit = PDFKit.new(html, page_size: 'A4')
pdf = kit.to_pdf
File.write("#{output_path}/observations-info.pdf", pdf)
