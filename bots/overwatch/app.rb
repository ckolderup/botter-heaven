require 'twitter'
require 'tempfile'
require 'rmagick'
require 'dotenv'
require 'ostruct'
require 'open-uri'
require 'discordrb/webhooks'
require_relative '../../lib/options'

include Magick

Dotenv.load
Options.read

class ImgurError < StandardError; end

def random_text
  "PLAY OF THE GAME"
end

def search_url(query, page)
  "https://api.imgur.com/3/gallery/search/time/#{page}?q=#{query}"
end

def curl_cmd(client_id, url)
  "curl -s -H \"Authorization: Client-ID #{client_id}\" \"#{url}\""
end

def random_noun
  "cat+OR+dog+OR+baby"
end

def random_imgur_url
  page = (1..100).to_a.sample
  noun = random_noun
  json = `#{curl_cmd(ENV['IMGUR_CLIENT_ID'], search_url(noun, page))}`
  response = JSON.parse(json, symbolize_names: true,
                              object_class: OpenStruct)
  sfw_urls = response.data.reject(&:nsfw)
                          .select(&:animated)
                          .select { |c| c.width >= 640 }
                          .select { |c| c.size >= 400_000 }
                          .map(&:mp4)
  raise ImgurError if sfw_urls.size == 0
  # puts "page: #{page} eligible: #{sfw_urls.size}"
  choice = sfw_urls.sample
  choice
end

def download_mp4(url)
  download = open(url)
  `rm -f /tmp/imgur.mp4`
  IO.copy_stream(download, '/tmp/imgur.mp4')
end

FFMPEG = "ffmpeg -y "#-hide_banner -loglevel panic"

def process_mp4s
  random_intro = Dir.glob("intros/*.mp4").sample
  `#{FFMPEG} -i #{random_intro} -vf "setsar=1:1, scale=640:-1, crop=640:360" -r 30 -aspect 16:9 /tmp/cropped-intro.mp4`
  `#{FFMPEG} -i /tmp/imgur.mp4 -vf "pad=max(iw\\,ih*(16/9)):ow/(16/9):(ow-iw)/2:(oh-ih)/2, setsar=1:1" -s 640x360 -aspect 16:9 -t 20 -r 30 /tmp/cropped.mp4`
  `#{FFMPEG} -i /tmp/cropped-intro.mp4 -i /tmp/cropped.mp4 -filter_complex "[0:v:0] [1:v:0] concat=n=2:v=1 [v]" -map "[v]" /tmp/final.mp4`
  `#{FFMPEG} -i music.mp3 -i /tmp/final.mp4 -c:v libx264 -pix_fmt yuv420p -profile:v high -c:a aac -profile:a aac_low -shortest -b:v 5000k -b:a 384k -ar 44100 -ac 2 -bf 2 -g 30 /tmp/playofthegame.mp4`
end

def cleanup
  `rm -f /tmp/imgur.mp4 /tmp/cropped-intro.mp4 /tmp/cropped.mp4 /tmp/final.mp4 /tmp/playofthegame.mp4`
end

client = Twitter::REST::Client.new do |config|
  config.consumer_key       = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret    = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_OAUTH_TOKEN']
  config.access_token_secret = ENV['TWITTER_OAUTH_SECRET']
end

begin
  tries ||= 4
  random_imgur_url
  download_mp4(random_imgur_url)
  process_mp4s

  if Options.get(:discord)
    client = Discordrb::Webhooks::Client.new(url: ENV['DISCORD_WEBHOOK_URL'])
    client.execute do |builder|
      puts `ls -alh /tmp/playofthegame.mp4`
      builder.file = File.new("/tmp/playofthegame.mp4")
    end
  end

  if Options.get(:twitter)
    client.update_with_media(random_text, File.new('/tmp/playofthegame.mp4'))
  end
rescue ImgurError, Twitter::Error => e
  puts e.message
  retry unless (tries -= 1).zero?
end
cleanup
