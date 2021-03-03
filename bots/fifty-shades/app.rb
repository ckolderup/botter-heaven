require 'tempfile'
require 'twitter'
require 'tempfile'
require 'rmagick'
require 'ostruct'
require 'discordrb/webhooks'

require_relative '../../lib/options'
require_relative '../../lib/mastodon'
require_relative '../../lib/env'

include Magick
Options.read

mastodon = MastodonPost.new('https://botsin.space', Env['MASTODON_ACCESS_KEY'])

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
  begin
    tries ||= 5
    noun = random_noun
    json = `#{curl_cmd(Env['IMGUR_CLIENT_ID'], search_url(noun))}`
    response = JSON.parse(json, symbolize_names: true,
      object_class: OpenStruct)
    sfw_urls = response.data.reject(&:nsfw)
      .reject(&:animated)
      .select(&:height)
      .select { |i| i.height.fdiv(i.width) > 1.2 }
      .map(&:link)

    choice = sfw_urls.sample
    puts "#{noun} resulted in #{choice}"
    if choice.nil?
      puts "retrying..."
      raise StandardError
    end
  rescue StandardError => e
    retry unless (tries -= 1).zero?
  end

  choice
end

def image(url)
  file = Tempfile.new('last_panel')
  file.write(`curl -s #{url}`)
  file.rewind
  bin = File.open(file,'r'){ |f| f.read }
  image = Image.from_blob(bin).first
  image.change_geometry!('500x') { |c,r,i| i.resize!(c,r) }


  template = Image.read("./peloton-template.png").first
  combined = (ImageList.new << template << image).append(true)

  file.write(combined.to_blob)
  file.rewind
  file
end

twitter_client = Twitter::REST::Client.new do |config|
  config.consumer_key       = Env['TWITTER_CONSUMER_KEY']
  config.consumer_secret    = Env['TWITTER_CONSUMER_SECRET']
  config.access_token        = Env['TWITTER_OAUTH_TOKEN']
  config.access_token_secret = Env['TWITTER_OAUTH_SECRET']
end

text = random_text
the_image = image(random_imgur_url)

if Options.get(:discord)
  discord_client = Discordrb::Webhooks::Client.new(url: Env['DISCORD_WEBHOOK_URL'])
  discord_client.execute do |builder|
    `cp #{the_image.path} /tmp/50shades.png`
    builder.file = File.new("/tmp/50shades.png")
  end
end

if Options.get(:twitter)
  # post to Twitter
  begin
    tries ||= 5
    twitter_client.update_with_media(text, the_image)
  rescue Twitter::Error => e
    retry unless (tries -= 1).zero?
  end
end

if Options.get(:masto)
  mastodon.submit(
    text,
    [the_image],
    ['']
  )
end
