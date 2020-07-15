require 'tempfile'
require 'twitter'
require 'rmagick'
require 'discordrb/webhooks'
require_relative '../../lib/options'
require_relative '../../lib/env'
include Magick

Options.read

client = Twitter::REST::Client.new do |config|
  config.consumer_key       = Env['TWITTER_CONSUMER_KEY']
  config.consumer_secret    = Env['TWITTER_CONSUMER_SECRET']
  config.access_token        = Env['TWITTER_OAUTH_TOKEN']
  config.access_token_secret = Env['TWITTER_OAUTH_SECRET']
end

def image(text)
  image = Image.new(800, 450) do
    self.background_color = 'gray20'
  end

  draw = Draw.new

  text_width = 750
  text_height = 320
  text_margin = 60
  text_y = 200
  char_width = 20
  font_size = 48

  text = text.split(' ').map { |i| i.scan(/[^\s]{1,18}/).join("\n")}.join(' ')
  wrap_text = text.scan(/\S.{0,#{char_width}}\S(?=\s|$)|\S+/).join("\n")

  text_y = (4 - wrap_text.count("\n") * 25) + text_y

  draw.annotate(image, text_width, text_height, text_margin, text_y, wrap_text) do
    self.font = './GoodBadMan.otf'
    self.pointsize = font_size
    self.fill = 'AntiqueWhite1'
    self.text_antialias = true
    self.stroke_width = 2
  end

  file = Tempfile.new(['output', '.png'])
  image.format = 'PNG'
  file.write(image.to_blob)
  file.rewind
  file
end


users = ['pokemon_ebooks']

tweets = client.user_timeline(users.sample, count: 1000).map(&:text)
          .reject { |t| t.split('').include?('@') || t.split('').include?('/') }

cards = (0..3).to_a.map do |try|
  rendered = image("\"#{tweets.sample}\"")
  `ffmpeg -y -loop 1 -i #{rendered.path} -c:v libx264 -t 3 -pix_fmt yuv420p -vf scale=320:240 /tmp/output-#{try}.mp4; echo /tmp/output-#{try}.mp4 `
end.map(&:chomp)

movies = (0..3).to_a.map do |try|
  filename = Dir.glob("mp4s/*.mp4").sample
  length = `ffprobe -i #{filename} -show_entries format=duration -v quiet -of csv="p=0" `.to_i
  start = (10..((length-10)/10).floor*10).to_a.sample
  `ffmpeg -y -ss #{start} -i #{filename} -t 4 -c copy -an /tmp/movie-#{try}.mp4; echo /tmp/movie-#{try}.mp4`
end.map(&:chomp)

concat_list = movies.zip(cards).flatten.compact

mpegs = concat_list.map do |file|
  intermediate = file.gsub('mp4', 'ts')
  `ffmpeg -y -i #{file} -c copy -bsf:v h264_mp4toannexb -f mpegts #{intermediate}; echo #{intermediate}`
end.map(&:chomp)

`ffmpeg -y -i  "concat:#{mpegs.join('|')}" -c copy /tmp/silent-film.mp4`
puts "ffmpeg -y -i \"concat:#{mpegs.join('|')}\" -c copy -an /tmp/silent-film.mp4"

if Options.get(:twitter)
  client.update_with_media("", File.new('/tmp/silent-film.mp4'))
end

if Options.get(:discord)
  discord = Discordrb::Webhooks::Client.new(url: Env['DISCORD_WEBHOOK_URL'])
  discord.execute do |builder|
    puts `ls -alh /tmp/silent-film.mp4`
    builder.file = File.new("/tmp/silent-film.mp4")
  end
end
