require 'giantbomb'
require 'dotenv'
require 'twitter'
require 'rmagick'
require 'open-uri'
require 'tempfile'
require 'discordrb/webhooks'
require_relative '../../lib/options'

include Magick

Dotenv.load
Options.read

GiantBomb::Api.key(ENV['GIANT_BOMB_API_KEY'])

def game_name_and_image_url
  images = nil
  while images.nil? do
    game = GiantBomb::Game.detail((1..51900).to_a.sample)
    #puts "checking #{game.name} (ID #{id}) for images (#{game.inspect})"
    next if game.images.nil?
    images = game.images.map { |imageset| imageset['super_url'] }
    #puts "found #{images.size} images"
    break unless images.size == 0
  end
  [game.name, images.sample]
end

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_OAUTH_TOKEN']
  config.access_token_secret = ENV['TWITTER_OAUTH_SECRET']
end

template_options = [
  "but with guns",
  "But With Guns",
  "but with... guns?",
  "but... with guns ;)",
  "but with guns!!!",
  "but with GUNS"
]

def some_guns
  gun_filenames = Dir.glob("./guns/*.png")
  gun_count = [1,1,1,2,2,2,3,3,3,3,3,4,4,5,6,7].sample
  gun_filenames.sample(gun_count).map do |filename|
    Image.read(filename).first
  end
end

def put_some_guns_on_it(file)
  img = Image.from_blob(file.read).first
  coords = (1..7).to_a.map { |x| (1..7).to_a.map { |y| [x.to_f/10, y.to_f/10] } }
                 .flatten(1).shuffle
  some_guns.each_with_index do |gun, idx|
    gun.background_color = 'none'
    scale = 1/(2..4).to_a.sample.to_f
    # rotate the gun (-40..40) degrees
    gun = gun.rotate((-40..40).to_a.sample)
    gun = gun.resize_to_fit((img.columns * scale).to_i, (img.rows * scale).to_i)

    # place it in one of four quadrants (with a small offset)
    img.composite!(gun, (coords[idx][0] * img.columns).to_i,
                        (coords[idx][1] * img.rows).to_i,
                   OverCompositeOp)
  end

  tempfile = Tempfile.new(['processed', '.png'])
  img.resize_to_fit!(550, 550)
  img.write(tempfile.path)
  tempfile
end


new_file = nil
tries = 5
begin
  #puts "finding a game..."
  result = game_name_and_image_url
  template = template_options.sample
  raise if result[1].nil?
  #puts "got one. modifying..."
  file = open(result[1])
  new_file = put_some_guns_on_it(file)
  #puts "modified"
rescue StandardError => e
  puts e.message
  puts e.backtrace
  puts "retrying (retries remaining: #{tries})"
  exit if (tries -= 1).zero?
  retry
end

if Options.get(:twitter)
  client.update_with_media("#{result[0]} #{template}", new_file)
end

if Options.get(:discord)
  `cp #{new_file.path} /tmp/butwithguns.png`
  client = Discordrb::Webhooks::Client.new(url: ENV['DISCORD_WEBHOOK_URL'])

  client.execute do |builder|
    builder.content = "#{result[0]} #{template}"
    builder.file = File.new("/tmp/butwithguns.png")
  end
end

