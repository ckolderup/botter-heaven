require 'tempfile'
require 'twitter'
require 'mastodon'
require 'tempfile'
require 'rmagick'
require 'dotenv'
require 'ostruct'
require 'discordrb/webhooks'
require_relative '../../lib/options'

include Magick
Dotenv.load
Options.read

def random_text
  ["My desires are... Unconventional",
  "So show me",
  "Oh my god",
  "No way"].sample
end

def search_url(query)
  "https://api.imgur.com/3/gallery/search?q=#{query}"
end

def curl_cmd(client_id, url)
  "curl -s -H \"Authorization: Client-ID #{client_id}\" \"#{url}\""
end

def random_noun
  File.readlines('./words.txt').sample.chomp
end

def random_imgur_url
  noun = random_noun
  json = `#{curl_cmd(ENV['IMGUR_CLIENT_ID'], search_url(noun))}`
  response = JSON.parse(json, symbolize_names: true,
  object_class: OpenStruct)
  sfw_urls = response.data.reject(&:nsfw)
  .reject(&:animated)
  .select(&:height)
  .select { |i| i.height.fdiv(i.width) > 1.2 }
  .map(&:link)

  choice = sfw_urls.sample
  puts "#{noun} resulted in #{choice}"
  choice
end

def image(url)
  file = Tempfile.new('last_panel')
  file.write(`curl -s #{url}`)
  file.rewind
  bin = File.open(file,'r'){ |f| f.read }
  image = Image.from_blob(bin).first
  image.change_geometry!('500x') { |c,r,i| i.resize!(c,r) }


  template = Image.read("./template.png").first
  combined = (ImageList.new << template << image).append(true)

  file.write(combined.to_blob)
  file.rewind
  file
end

client = Twitter::REST::Client.new do |config|
  config.consumer_key       = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret    = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_OAUTH_TOKEN']
  config.access_token_secret = ENV['TWITTER_OAUTH_SECRET']
end

mastodon_client = Mastodon::REST::Client.new(base_url: 'https://botsin.space', bearer_token: ENV['MASTODON_ACCESS_KEY'])

text = random_text
the_image = image(random_imgur_url)

if Options.get(:discord)
  client = Discordrb::Webhooks::Client.new(url: ENV['DISCORD_WEBHOOK_URL'])
  client.execute do |builder|
    `cp #{the_image.path} /tmp/50shades.png`
    builder.file = File.new("/tmp/50shades.png")
  end
end

if Options.get(:twitter)
  # post to Twitter
  begin
    tries ||= 5
    client.update_with_media(text, the_image)
  rescue Twitter::Error => e
    retry unless (tries -= 1).zero?
  end
end

if Options.get(:masto)
  # post to Mastodon
  media = mastodon_client.upload_media(the_image)
  mastodon_client.create_status(text, media_ids: [media.id])
end

