#!/usr/bin/env ruby
# frozen_string_literal: true

require 'dotenv/load'
require 'kramdown'

output_path = File.expand_path(ENV['OUTPUT_PATH'])
BASE_URL = "https://tapestryjournal.com/s/#{ENV['SCHOOL']}/observation"

md =  "# Tapestry observations for #{ENV['NAME']}\n\n"

Dir.each_child(output_path) do |observation|
  observation_path="#{output_path}/#{observation}/"
  next unless Dir.exists?(observation_path)
  puts "#{output_path}/#{observation}/"
  meta = File.read("#{observation_path}observations-#{observation}.txt")
  md += meta
  Dir.each_child("#{output_path}/#{observation}") do |observation_file|
    next if observation_file =~ /observation.*\.txt/
    observation_file_path="#{observation}/#{observation_file}"
    if observation_file =~ /.*\.mp4/
      md += "<video src='#{observation_file_path}' alt='#{observation_file_path}' controls></video><br/><br/>\n\n"
    else
      md += "[![#{observation_file_path}](#{observation_file_path})](#{observation_file_path})\n\n"
    end
  end
  md += "<#{BASE_URL}/#{observation}>\n\n"
end

File.write("#{output_path}/index.md", md)
html = Kramdown::Document.new(md).to_html
File.write("#{output_path}/index.html", html)

