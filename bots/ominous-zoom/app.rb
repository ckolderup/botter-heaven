require 'opencv'
require 'rmagick'
require 'open-uri'
require 'rest-client'
require 'json'
require 'dotenv'
require 'twitter'
require 'mastodon'
require_relative 'wikimedia'
require 'optparse'

include OpenCV
include Magick

Dotenv.load

class Zoomhance
  def self.run
    options = {}
    OptionParser.new do |opts|
        opts.banner = "Usage: example.rb [options]"

        opts.on("-t", "--tweet", "Tweet instead of printing") do |t|
            options[:tweet] = true
        end
    end.parse!

    tries ||= 5
    begin
      path_or_url = ARGV[0]
      loop do
        break unless path_or_url.nil?
        path_or_url = Wikimedia.fetch_random_image
      end
      file = open(path_or_url)
      video_paths = [generate_video(file,5-tries)]
      image_paths = generate_images(file,5-tries,true)
      p_distrib = Array.new(75, image_paths) + Array.new(25, video_paths)
      tweet(p_distrib.shuffle.sample) if options[:tweet]
    rescue StandardError => e
      puts e.message
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

  def self.tweet(image_paths)
    client = twitter_client

    prefix = Array.new(20, '') << '*whispers* ' << '*quietly* ' << '*hissing* ' << '*humming* '
    dorz = Array.new(99, 'z') << 'd'

    text = "#{prefix.sample}#{dorz.sample}oo#{'o' * rand(10)}m".send([:upcase, :downcase].sample)
    #puts text
    client.update_with_media(text, image_paths.map { |i| File.new(i) })

    masto = masto_client
    image_ids = image_paths.map do |image_path|
      masto.upload_media(File.new(image_path)).id
    end

    masto.create_status(text, nil, image_ids)
  end

  def self.generate_video(file,idx)
    ipl_image = IplImage::load(file.path)
    rm_image = Image.read(file.path).first

    op = CvHaarClassifierCascade::load('haarcascade_frontalface_alt.xml')

    chosen = op.detect_objects(ipl_image).to_a.sample

    raise "no face found" if chosen.nil?

    face_center_x = chosen.center.x
    face_center_y = chosen.center.y


    height = rm_image.rows
    width = rm_image.columns
    og_height = height
    og_width = width

    avg_scale_factor = 50 * ((chosen.width.to_f / width) + (chosen.height.to_f / height) / 2)
    step = [avg_scale_factor / 300, 0.0005].max

    if height > width
      height = [600, height + (height % 2)].min
      width = (width.to_f * height.to_f / og_height).to_i
      width = width + (width % 2)
    else
      width = [800, width + (width % 2)].min
      height = (height.to_f * width.to_f / og_width).to_i
      height = height + (height % 2)
    end
    scale = "#{width}:#{height}"

    out_video_path = "output/output-#{idx}.mp4"
    audio_library_path = 'sounds/21st-of-may'
    audio_path = Dir.glob("#{audio_library_path}/*.mp3").sample
    input = "-i #{file.path}"
    audio_input = "-i #{audio_path}"
    vid_params = "-c:v libx264 -r 30 -pix_fmt yuvj420p"
    command = "ffmpeg -y -loglevel fatal -loop 1 #{input} #{audio_input} #{vid_params}"
    zoom_speed = step
    x_comp = "'iw*#{face_center_x/og_width}-(iw/zoom/2)'"
    y_comp = "'ih*#{face_center_y/og_height}-(ih/zoom/2)'"
    pan = "x=#{x_comp}:y=#{y_comp}"
    zoompan = "-vf \"scale=iw*2:ih*2,zoompan=z='zoom+#{zoom_speed}':d=500:#{pan},scale=#{scale}\""
    duration = "-t 10"
    input_map = "-map 0:0 -map 1:0"
    `#{command} #{zoompan} #{duration} #{input_map} #{out_video_path}`
    out_video_path
  end

  def self.generate_images(file, try, local=false)
    ipl_image = IplImage::load(file.path)
    rm_image = Image.read(file.path).first

    op = CvHaarClassifierCascade::load('haarcascade_frontalface_alt.xml')

    chosen = op.detect_objects(ipl_image).to_a.sample

    raise "no face found" if chosen.nil?

    face_center_x = chosen.center.x
    face_center_y = chosen.center.y


    original_height = rm_image.rows
    original_width = rm_image.columns

    wide_ratio = (1 - (chosen.width.to_f / original_width)) * 100
    tall_ratio = (1 - (chosen.height.to_f / original_height)) * 100
    ratio = (wide_ratio + tall_ratio) / 2


    image_paths = []
    [0,1,2,3].each do |idx|
      factor = 0.95
      zoom = (idx.to_f / 3) * ratio * factor
      new_width = original_width * (1 - zoom.to_f/100) * factor
      offset_x = [face_center_x - (new_width.to_f / 2), 0].max.to_i
      if offset_x + new_width > original_width
        offset_x = offset_x - (offset_x + new_width - original_width)
      end

      new_height = original_height * (1 - zoom.to_f/100) * factor
      offset_y = [face_center_y - (new_height.to_f / 2), 0].max.to_i
      if offset_y + new_height > original_height
        offset_y = offset_y - (offset_y + new_height - original_height)
      end

      new_image = rm_image.crop(offset_x, offset_y, new_width, new_height)
      new_image.resize_to_fit!(original_width, original_height)
      filename = "output/output-#{try}-#{idx}.jpg"
      new_image.write(filename)
      image_paths << filename

      #debug_draw(offset_x, offset_y, offset_x + new_width,
      #           offset_y + new_height, "#{try}-#{idx}")
    end
    image_paths
  end

  def self.debug_draw(img, x, y, width, height, suffix)
    drawn_image = img.copy
    rect = Draw.new
    rect.stroke('red')
    rect.fill('transparent')
    rect.rectangle(x, y, x + width, y + height)
    rect.draw(drawn_image)
    drawn_image.write("output/output-debug-#{suffix}.jpg")
  end
end

Zoomhance.run
