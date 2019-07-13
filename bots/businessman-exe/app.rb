require 'tempfile'
require 'twitter'
require 'mastodon'
require 'optparse'
require 'rmagick'
require 'dotenv'

require_relative '../../lib/options'

include Magick

Dotenv.load
Options.read

SCUMMFONT = File.join(__dir__, 'scumm.ttf')

@firsts =       File.readlines(File.join(__dir__, "first.txt"))
@surnames =     File.readlines(File.join(__dir__,"surname.txt"))
@ranks =        File.readlines(File.join(__dir__, "rank.txt"))
@departments =  File.readlines(File.join(__dir__, "department.txt"))
@titles =       File.readlines(File.join(__dir__, "title.txt"))

def computer_company
  company_front = %w[Elec Inter Macro Globo Hyper Infra]
  company_back = %w[tron node trode soft systems ]
  "#{company_front.sample}#{company_back.sample}"
end

def named_firm
  "#{@surnames.sample.chomp} & #{@surnames.sample.chomp}"
end

def dumb
  first = %w[Global Syndicated Amalgamated Professional International Distributed]
  last = %w[Meats Futures Industries Metals Investments Logging Infrastructure Instruction Development Research Systems]
  designator = %w[Inc Corp LLC]
  "#{first.sample} #{last.sample} #{designator.sample}"
end

def acronym
  acro = (1..4).reduce("") {|i| i << ('A'..'Z').to_a.sample}
  acro[2] = '&'
  acro
end

def image(name, title, company)
  file = Tempfile.new('bizman')
  file.write(`curl -s "http://www.avatarpro.biz/avatar?s=500"`)
  file.rewind
  bin = File.open(file,'r'){ |f| f.read }
  image = Image.from_blob(bin).first
  palette = Image.read(File.join(__dir__, 'palette.png')).first
  image = image.map(palette)
  append = Image.new(750, 500) do
    self.background_color = 'black'
  end

  draw = Draw.new

  text_width = 550
  text_height = 50
  text_margin = 15
  name_y = 260
  title_y = 400
  company_y = 475

  draw.annotate(append, text_width, text_height, text_margin, name_y, name) do
    self.font = SCUMMFONT
    self.pointsize = 56
    self.fill = 'white'
    self.text_antialias = true
    self.stroke_width = 2
    self.font_weight = 900
  end

  draw.annotate(append, text_width, text_height, text_margin, title_y, title) do
    self.font = SCUMMFONT
    self.pointsize = 24
    self.fill = 'white'
    self.text_antialias = true
    self.stroke_width = 2
  end

  draw.annotate(append, text_width, text_height, text_margin, company_y, company) do
    self.font = SCUMMFONT
    self.pointsize = 48
    self.fill = 'white'
    self.text_antialias = true
    self.stroke_width = 2
  end

  combined = (ImageList.new << image << append).append(false)

  file.write(combined.to_blob)
  file.rewind
  file
end

company = %w[named_firm computer_company dumb acronym]

@name = nil
@title = nil
@company = nil
length = 141
while length > 140 do
  @name = "#{@firsts.sample.chomp} #{@surnames.sample.chomp}"
  @title = "#{@ranks.sample.chomp} #{@departments.sample.chomp} #{@titles.sample.chomp}"
  @company = "#{send(company.sample)}"
  out = "#{@name}, #{@title} at #{@company}"
  length = out.length
end

rendered = image(@name, @title, @company)

if Options.get(:tweet) then
  client = Twitter::REST::Client.new do |config|
    config.consumer_key       = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret    = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_OAUTH_TOKEN']
    config.access_token_secret = ENV['TWITTER_OAUTH_SECRET']
  end
  client.update_with_media(out, rendered)
end

if Options.get(:masto) then
  masto_client = Mastodon::REST::Client.new(base_url: 'https://botsin.space', bearer_token: ENV['MASTODON_ACCESS_KEY'])
  masto_media = masto_client.upload_media(rendered)
  masto_client.create_status(out, media_ids: [masto_media.id])
end
