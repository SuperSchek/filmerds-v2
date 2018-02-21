#!/usr/bin/env ruby

##### NOTES #####
# This script needs a .env file with ENGINE_EMAIL and ENGINE_API_KEY to work

# require 'uri'
# file_url = MyObject.first.file.url
#
# url = URI.parse(file_url)
# req = Net::HTTP::Head.new url.path
# res = Net::HTTP.start(url.host, url.port) {|http|
#   http.request(req)
# }
#
# file_length = res["content-length"]

require 'yaml'
require 'locomotive/coal'
require 'dotenv/load'
require 'net/http'

# Load data file (should be synced with bundle exec wagon sync)
podcasts = YAML.load_file('../data/podcasts.yml')

# Initiate LocomotiveCMS Coal Client
client = Locomotive::Coal::Client.new('https://engine.sanderschekman.com', { email: ENV['ENGINE_EMAIL'], api_key: ENV['ENGINE_API_KEY'] })

# Sends a head request to the S3 URL and returns filesize in bytes
def get_filesize_s3(url)
  return "Get dat size yo"
end

# Adds filesize in bytes to s3_filesize property of entry on LocomotiveCMS using Coal
def set_filesize_engine(url)
  return "Set dat size yo"
end

# Loop over all entries
podcasts.each do |podcast|
  # Convert podcast Hash to array for easier handling
  podcast = podcast.to_a

  # puts podcast[0][1]["s3_url"]
end
