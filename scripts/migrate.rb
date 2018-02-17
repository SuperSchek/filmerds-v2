#!/usr/bin/env ruby

#  Data Legend
# 0 = id
# 1 = Title
# 2 = Content
# 3 = Date
# 4 = Categorieën
# 5 = Tags

require 'rubygems'
gem 'google-api-client', '>0.7'
require 'google/apis'
require 'google/apis/youtube_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'
require 'json'
require 'csv'

require 'open-uri'
require 'net/http'

class String
  def string_between_markers marker1, marker2
    self[/#{Regexp.escape(marker1)}(.*?)#{Regexp.escape(marker2)}/m, 1]
  end
end

def extract_name(title)
  # return content.string_between_markers('href="', '"')
  new_title = title.partition('| ').last
  if (new_title == "")
    new_title = title.partition(': ').last
  else
    new_title = title
  end
  return new_title
end

def extract_url(content)
  url = content.string_between_markers('href="', '"')
  if (!url)
    url = content.string_between_markers("href='", "'")
  end
  return url
end

def remove_attributes(content)
  # return content.string_between_markers('<', '>')
  return content.gsub(%r{</?[^>]+?>}, '')
end

def get_category(category)
  # Set uncommon or English categry's to their correct/Dutch counterpart
  case category
  when "Reviews"
    category = "Review"
  when "De Praattafel"
    category = "Praattafel"
  when "Discussion"
    category = "Discussie"
  when "Favorites"
    category = "Favorieten"
  when "Gametime"
    category = "Statafel"
  when "Roundtable Discussion"
    category = "Praattafel"
  when "Upcoming Releases"
    category = "Voorbeschouwing"
  else
    category = category
  end

  return category
end

#YouTube API Stuff!
# REPLACE WITH VALID REDIRECT_URI FOR YOUR CLIENT
REDIRECT_URI = 'http://localhost'
APPLICATION_NAME = 'YouTube Data API Ruby Tests'

# REPLACE WITH NAME/LOCATION OF YOUR client_secrets.json FILE
CLIENT_SECRETS_PATH = 'client_secret.json'

# REPLACE FINAL ARGUMENT WITH FILE WHERE CREDENTIALS WILL BE STORED
CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                             "youtube-quickstart-ruby-credentials.yaml")

# SCOPE FOR WHICH THIS SCRIPT REQUESTS AUTHORIZATION
SCOPE = Google::Apis::YoutubeV3::AUTH_YOUTUBE_READONLY

def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(
    client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: REDIRECT_URI)
    puts "Open the following URL in the browser and enter the " +
         "resulting code after authorization"
    puts url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: REDIRECT_URI)
  end
  credentials
end

# Initialize the API
service = Google::Apis::YoutubeV3::YouTubeService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

def search_list_by_keyword(service, part, found_vids, **params)
  params = params.delete_if { |p, v| v == ''}
  response = service.list_searches(part, params).to_json
  JSON.parse(response).fetch("items").each_with_index do |video, index|
    puts "#{index}: " + video.fetch("snippet").fetch("title")
    found_vids << video
  end
end


# site_client.contents.podcasts.create({
#   naam: 'Black Panther',
#   categorie: 'Review',
#   youtube_url: 'https://dikkeurlhier/vetniceidtje'
# })

# Iterate over all entries in CSV file.
CSV.foreach("./sample_data.csv", :headers => true) do |podcast|
  puts podcast[3]
  puts 'processing ' + podcast[1]
  puts "-------------------------------------------------------------"

  puts "De volgende Filmerds video\'s kwamen uit de query. Zit de juiste er bij? (Enter number of correct vid or 'no' to enter a url manually)"
  puts "\n"
  found_vids = []

  search_list_by_keyword(service, 'snippet', found_vids,
    max_results: 5,
    q: 'Filmerds ' + get_category(podcast[4]) + " | " + extract_name(podcast[1]),
    type: 'video')

  entered_data = gets.chomp
  youtube_url = ""
  thumbnail_url = ""
  if (entered_data == "0" || entered_data == "1" || entered_data == "2" || entered_data == "3" || entered_data == "4")
    entered_data = entered_data.to_i
    youtube_url = "https://www.youtube.com/watch?v=" + found_vids[entered_data].fetch("id").fetch("videoId")
    thumbnail_url = "https://i.ytimg.com/vi/" + found_vids[entered_data].fetch("id").fetch("videoId") + "/hqdefault.jpg"
  elsif (entered_data == "no" || entered_data == "n")
    puts "Enter a custom FULL (e.g. https://www.youtube.com/watch?v=luRMKAwdi0Y) url:"
    youtube_url = gets.chomp
    thumbnail_url = "https://i.ytimg.com/vi/" + youtube_url.partition('v=').last + "/hqdefault.jpg"
  end

  puts "\n"
  puts "\n"

  puts "Ziet deze data er goed uit?"
  puts "\n"

  puts "Originele naam: " + podcast[1]
  puts "Categorie: " + get_category(podcast[4])
  puts "Naam: " + extract_name(podcast[1])
  puts "Omschrijving: " + remove_attributes(podcast[2])
  puts "AWS S3 URL: " + extract_url(podcast[2])
  puts "YouTube URL: " + youtube_url
  puts "Thumbnail URL: " + thumbnail_url

  puts "\n"
  puts "Ziet dit er goed uit?"

  continue = gets.chomp

  filename = get_category(podcast[4]) + "_" + extract_name(podcast[1])
  filename = filename.gsub!(/[^0-9A-Za-z]/, '')

  File.open(filename + '.jpg', 'wb') do |img|
    img.write open(thumbnail_url).read
  end

  uri = URI.parse("https://engine.sanderschekman.com/locomotive/api/v3/content_types/podcasts/entries.json")
  http =  Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  req = Net::HTTP::Post.new("https://engine.sanderschekman.com/locomotive/api/v3/content_types/podcasts/entries.json")
  req['Content-Type'] = "application/json"
  req['X-Locomotive-Account-Token'] = "_kgPwMyd4sLXzrP6aZ8R"
  req['X-Locomotive-Account-Email'] = "aaschekman@icloud.com"
  req['X-Locomotive-Site-Handle'] = "filmerds-staging"

  thumb = open(filename + ".jpg")

  puts thumb

  req.body = {"content_entry": {
    "naam": extract_name(podcast[1]),
    "categorie": get_category(podcast[4]),
    "s3_url": extract_url(podcast[2]),
    "youtube_url": youtube_url,
    "omschrijving": remove_attributes(podcast[2])
  }}.to_json

  resp = http.start{|http| http.request(req)}

  puts resp.inspect

  File.delete filename + '.jpg'

  puts "\n"
  puts "\n"
  puts "\n"
  puts "-------------------------------------------------------------"
  # Extract name from post title
  # extract_name(podcast[1])

  # S3 Url
  # puts extract_url(podcast[2])

  # Category
  # puts get_category(podcast[4])

  # Description
  # puts remove_attributes(podcast[2])

  # If name only contains category (early praattafels) set raw name
  # if (extract_name(podcast[1]) == '')
  #   puts get_category(podcast[4]) + " | " + podcast[1]
  # else
  #   puts get_category(podcast[4]) + " | " + extract_name(podcast[1])
  # end
end
