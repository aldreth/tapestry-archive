#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dotenv/load'
require 'kramdown'

output_path = File.expand_path(ENV['OUTPUT_PATH'])
BASE_URL = "https://tapestryjournal.com/s/#{ENV['SCHOOL']}/observation"

md =  "# Tapestry observations for #{ENV['NAME']}\n\n"

observation_folders = Dir.entries(output_path).sort.reverse.select { |entry| entry[0] != "." }

observation_folders.each do |observation|
  observation_path="#{output_path}/#{observation}/"
  next unless Dir.exists?(observation_path)
  puts "#{output_path}/#{observation}/"
  meta = File.read("#{observation_path}observations-#{observation}.txt")
  md += meta
  Dir.entries("#{output_path}/#{observation}").sort.each do |observation_file|
    next if observation_file[0] == "."
    next if observation_file =~ /observation.*\.txt/
    observation_file_path="#{observation}/#{observation_file}"
    if observation_file =~ /.*\.mp4/
      md += "<video src='#{observation_file_path}' alt='#{observation_file_path}' controls></video>\n"
    else
      md += "[![#{observation_file_path}](#{observation_file_path})](#{observation_file_path})\n"
    end
  end
  md += "\n\n<#{BASE_URL}/#{observation}>\n\n"
end

File.write("#{output_path}/index.md", md)
html = Kramdown::Document.new(md).to_html
File.write("#{output_path}/index.html", html)

