require 'opencv'
require 'rmagick'
require 'open-uri'
require 'rest-client'
require 'json'
require_relative 'wikimedia'
require 'dotenv'
require 'twitter'
require 'mastodon'
require 'word_wrap'
require 'word_wrap/core_ext'
require_relative '../../lib/options'

include Magick
include OpenCV

Dotenv.load
Options.read

class IllustratedMe
  def self.run
    begin
      tries ||= 5

      path_or_url = ARGV[0]
      loop do
        break unless path_or_url.nil?
        path_or_url = Wikimedia.fetch_random_image
      end
      file = open(path_or_url)
      image_path = generate_image(file,5-tries,true)
      tweet(image_path) if options[:tweet]
    rescue StandardError => e
      puts e.message
      puts e.backtrace
      retry unless (tries -= 1).zero?
    end
  end

  def self.twitter_client
    Twitter::REST::Client.new do |config|
      config.consumer_key       = ENV['TWITTER_CONSUMER_KEY']
      config.consumer_secret    = ENV['TWITTER_CONSUMER_SECRET']
      config.access_token        = ENV['TWITTER_OAUTH_TOKEN']
      config.access_token_secret = ENV['TWITTER_OAUTH_SECRET']
    end
  end

  def self.masto_client
    Mastodon::REST::Client.new(base_url: 'https://botsin.space', bearer_token: ENV['MASTODON_ACCESS_KEY'])
  end

  def self.tweet(image_path)
    if Options.get(:twitter)
      client = twitter_client
      client.update_with_media('', File.new(image_path))
    end

    if Options.get(:masto)
      masto = masto_client
      id = masto.upload_media(File.new(image_path)).id
      masto.create_status('', media_ids: [id])
    end
  end

  def self.generate_image(file, try, local=false)
    ipl_image = IplImage::load(file.path)
    rm_image = ImageList.new(file.path)

    op = CvHaarClassifierCascade::load('haarcascade_frontalface_alt.xml')

    pois = op.detect_objects(ipl_image).to_a.sample(3)

    raise "multiple POI not found" if pois.size < 2

    # sample from the list of corresponding texts <= the size of the array
    pairs = pois.zip(random_subjects)

    orig_height = rm_image.rows.to_f
    orig_width = rm_image.columns.to_f

    rm_image.auto_orient!
    rm_image.resize_to_fit!(500, 500)

    height = rm_image.rows.to_f
    width = rm_image.columns.to_f

    pairs.each do |pair|
      poi = pair[0]
      text = pair[1]

      caption = Image.read("caption:#{balance(text)}") do
        self.font = './Arial Bold.ttf'
        self.fill = 'white'
        self.stroke = 'black'
        self.gravity = CenterGravity
        self.background_color = 'Transparent'
        self.pointsize = if text.split(' ').map(&:length).max > 5
                           (20..22).to_a.sample
                         else
                           (24..30).to_a.sample

        end
        self.size = "#{width * 0.33}x"
      end.first

      text_x = [
                 [poi.center.x * (width/orig_width),
                  width - caption.columns].min,
                  5
               ].max.to_i

      text_y = [
                 [poi.center.y * (height/orig_height),
                  height - caption.rows].min,
                  5
                ].max.to_i

      puts "caption: #{text} x: #{text_x} y: #{text_y}"
      puts "columns: #{caption.columns} rows: #{caption.rows}"

      rm_image = rm_image.composite(caption, text_x, text_y, OverCompositeOp)
    end
    rm_image.write('./out.jpg')
    'out.jpg'
  end

  def self.balance(text, width=8, fudge_factor=4)
    return text if text.nil? || text.length <= width

    lines = text.wrap(width).split('\n')

     while (orphan = lines.find_index { |x| x.length <= 3 }) != nil
       puts "lines: #{lines.size}"
       if orphan == 0
         if lines[orphan + 1].length + lines[orphan].length <= width + fudge_factor
           lines[orphan + 1] += ' ' + lines[orphan]
           lines.delete_at(orphan)
         end
       elsif orphan == lines.length - 1
         if lines[orphan - 1].length + lines[orphan].length <= width + fudge_factor
           lines[orphan - 1] += ' ' + lines[orphan]
           lines.delete_at(orphan)
         end
       else
         if (lines[orphan - 1].length < lines[orphan + 1].length) &&
          (lines[orphan - 1].length + lines[orphan].length <= width + fudge_factor)
           lines[orphan - 1] += ' ' + lines[orphan]
         else
           lines[orphan + 1] += ' ' + lines[orphan]

         end
         lines.delete_at(orphan)
       end
     end

     lines.join('\n')
  end

  def self.random_subjects
    [
      ['me'],
      ['you'],
      ['me', 'you'],
      ['me', 'everyone else'],
      ['you', 'everyone else'],
      ['us', 'them'],
      [Date.today.year.to_s, (Date.today.year-1).to_s]
    ].sample.push(IO.readlines('xing_actions.txt').sample).shuffle
  end
end


IllustratedMe.run
