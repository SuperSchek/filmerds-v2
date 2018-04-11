#!/usr/bin/env ruby

##### NOTES #####
# This script needs a .env file with ENGINE_EMAIL and ENGINE_API_KEY to work


require 'yaml'
require 'locomotive/coal'
require 'dotenv/load'
require 'net/http'
require 'uri'

# Initiate LocomotiveCMS Coal Client
client = Locomotive::Coal::Client.new('https://engine.sanderschekman.com', { email: ENV['ENGINE_EMAIL'], api_key: ENV['ENGINE_API_KEY'] })
site = client.sites.by_handle('filmerds')
site_client = client.scope_by(site)

def get_audio_length(filepath)
  # Clean up the url to prevent S3 from returning application/json responses
  filepath = filepath.gsub "&amp;", "%26"
  filepath = filepath.gsub "&", "%26"  

  pipe = "ffmpeg -i #{filepath} 2>&1 | grep 'Duration' | cut -d ' ' -f 4 | sed s/,//"
  command = `#{pipe}`

  duration = command.slice(0..(command.index('.')))

  return duration[0..-2]
end

def set_duration_engine(slug, duration, site_client)
  site_client.contents.podcasts.update(slug, { podcast_length: duration})
end

# Loop over all entries
page = 1
while page do
  podcasts = site_client.contents.podcasts.all({}, page: page)
  podcasts.each do |podcast|
    if (podcast.podcast_length.nil? || podcast.podcast_length.length < 1)
      # We're gonna get to work
      puts "----------------------------------------------"
      puts "Setting duration for " + podcast.categorie + " | " + podcast.naam
      puts podcast.s3_url.to_s
      
      # Get duration
      duration = get_audio_length(podcast.s3_url.to_s)
      puts "S3 duration is " + duration + "!"

      # Set duration on Engine
      set_duration_engine(podcast._slug, duration, site_client)
      puts "Updated duration to " + duration + " on the engine!"
    else
      # This entry can be skipped
      puts "----------------------------------------------"    
      puts "Skipped " + podcast.categorie + " | " + podcast.naam
    end
    
  end
  page = podcasts._next_page
end

# Nice message to show when work is done
puts "Durations were updated for all entries!"