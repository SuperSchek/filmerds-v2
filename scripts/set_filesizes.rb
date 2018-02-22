#!/usr/bin/env ruby

##### NOTES #####
# This script needs a .env file with ENGINE_EMAIL and ENGINE_API_KEY to work


require 'yaml'
require 'locomotive/coal'
require 'dotenv/load'
require 'net/http'
require 'uri'

# Load data file (should be synced with bundle exec wagon sync)
podcasts = YAML.load_file('../data/podcasts.yml')

# Initiate LocomotiveCMS Coal Client
client = Locomotive::Coal::Client.new('https://engine.sanderschekman.com', { email: ENV['ENGINE_EMAIL'], api_key: ENV['ENGINE_API_KEY'] })
site = client.sites.by_handle('filmerds-staging')
site_client = client.scope_by(site)

# Sends a head request to the S3 URL and returns filesize in bytes
def get_filesize_s3(url)
  # Clean up the url to prevent S3 from returning application/json responses
  url = url.gsub "&amp;", "%26"

  # Build the request object
  uri = URI.parse(url)
  http =  Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  req = Net::HTTP::Head.new(url)

  # Make the request
  resp = http.start{|http| http.request(req)}

  # Return the content-length value in the response
  return resp["content-length"]
end

# Adds filesize in bytes to s3_filesize property of entry on LocomotiveCMS using Coal
def set_filesize_engine(slug, filesize, site_client)
  site_client.contents.podcasts.update(slug, { s3_filesize: filesize})
end

# Loop over all entries
podcasts.each do |podcast|
  # Convert podcast Hash to array for easier handling
  podcast = podcast.to_a
  
  puts "----------------------------------------------"
  puts podcast[0][1]["categorie"] + " | " + podcast[0][1]["naam"]

  # Check if current entry already contains an s3_filesize value. If so, skip it
  if (podcast[0][1]["s3_filesize"].nil?)
    # Get filesize
    filesize = get_filesize_s3(podcast[0][1]["s3_url"])
    puts "S3 filesize is " + filesize + " bytes!"

    # Set filesize on Engine
    set_filesize_engine(podcast[0][1]["_slug"], filesize, site_client)
    puts "Updated filesize to " + filesize + " on the engine!"
  else
    puts "Filesize already set, skipping entry."
  end
end

# Nice message to show when work is done
puts "Filesizes were updated for all entries!"
