require 'noun-project-api'
require 'dotenv'
require 'squib'
require 'open-uri'
require 'colourlovers'
require 'color'
require 'wordnik'
require 'twitter'
require 'mastodon'

Dotenv.load

NounProjectApi.configure do |config|
  config.public_domain = true
end

Wordnik.configure do |config|
  config.api_key = ENV['WORDNIK_API_KEY']
end

twitter = Twitter::REST::Client.new do |config|
    config.consumer_key       = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret    = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_OAUTH_TOKEN']
    config.access_token_secret = ENV['TWITTER_OAUTH_SECRET']
end

mastodon_client = Mastodon::REST::Client.new(base_url: 'https://botsin.space', bearer_token: ENV['MASTODON_ACCESS_KEY'])

def random_word
  File.readlines('./words.txt').sample.chomp
end

def icon_path(word)
  "tmp/icon-#{word}.png"
end

def output_paths
  [
    './_output/hand.png',
    './_output/card_00.png',
    './_output/card_01.png',
    './_output/card_02.png'
  ]
end

def white_or_black_text(hex)
  Color::RGB.by_hex(hex).brightness <= 0.5 ? '#FFF' : '#000'
end

def common_rules
  File.readlines('./rules/common.txt').sample(3).map(&:chomp)
end

def rare_rule
  File.readlines('./rules/rare.txt').sample.chomp
end

def epic_rule
  File.readlines('./rules/epic.txt').sample.chomp
end

icons_finder = NounProjectApi::IconsRetriever.new(ENV['NOUN_PROJECT_TOKEN'], ENV['NOUN_PROJECT_SECRET'])

words = []

while words.size < 3
  word = random_word
  choices = icons_finder.find(word)
  if choices && choices.size > 0
    File.open(icon_path(word), 'wb') do |fo|
      fo.write open(choices.sample.preview_url).read
    end
    words << word
  end
end

cl_client = Colourlovers::Client.new
colors = cl_client.random_palette["colors"].map {|c| "##{c}"}
text_colors = colors.map { |c| white_or_black_text(c) }

rules_texts = case rand(1..100)
              when 1..50   then common_rules
              when 51..90  then common_rules[0..1].unshift(rare_rule)
              when 91..100 then common_rules[0..1].unshift(epic_rule)
              end

rules_texts.each_with_index do |text, idx|
  text.gsub!(/%%([a-z\-]+)%%/) do |match|
    begin
      response = Wordnik.word.get_related(words[idx], type: $1)
      word = response.first["words"].sample
    rescue StandardError
      word = random_word
    end
    word
  end
end

Squib::Deck.new(layout: 'hand.yml', cards: words.size, width: 850, height: 1150) do
  rect x: 50, y: 50, width: 750, height: 1050, x_radius: 38, y_radius: 38, fill_color: colors, stroke_color: '#0000'

  png  x: 325, y: 250, width: 200, height: 200, mask: text_colors, file: words.map { |w| icon_path(w)}
  text x: 75, y: 475,  width: 700, str: words, font: 'Bookman Antique 24', align: :center, color: text_colors
  text x: 125, y: 750,  width: 600, height: 175, str: rules_texts, font: 'Helvetica Neue 10', align: :center, color: text_colors

  save_png
  hand
end

#post to twitter
media_files = output_paths.map do |filename|
 File.new(filename)
end

text = "New cards: #{words.join(', ')}"
twitter.update_with_media(text, media_files)

#post to Mastodon
masto_media_ids = output_paths.map do |filename|
  mastodon_client.upload_media(File.new(filename)).id
end

mastodon_client.create_status(text, media_ids: masto_media_ids)

#cleanup
words.each do |a_word|
  `rm #{icon_path(a_word)}`
end

output_paths.each do |path|
  `rm #{path}`
end
