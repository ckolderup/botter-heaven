require 'json'
require 'dotenv'
require 'mastodon'
require_relative '../../lib/options'

Dotenv.load
Options.read

mastodon = Mastodon::REST::Client.new(base_url: 'https://botsin.space', bearer_token: ENV['MASTO_ACCESS_TOKEN'])

FRAMES = 11

def scale(val, pct)
  (val * (pct/100)).round
end

def scale_cpts(string, pct)
  cpts = string.split(' ')
  cpts.each_with_index do |cpt, idx|
    x, y = cpt.split(',').map(&:to_f)
    cpts[idx] = "#{scale(x, pct)},#{scale(y, pct)}"
  end
  cpts.join(' ')
end

filename = ARGV[0] || 'data.json'
file = File.read(filename)
data = JSON.parse(file)

animal = data['animals'].sample
celeb = data['celebs'].sample

puts "selected animal #{animal['file']}!"
puts "selected celeb #{celeb['file']}!"

animal_size = `identify -format "%w" #{animal['file']}`.to_f
celeb_size = `identify -format "%w" #{celeb['file']}`.to_f
size = [animal_size, celeb_size].min

if animal_size/celeb_size >= 1
  puts "scaling down animal..."
  pct = 100 * celeb_size/animal_size

  # do the resize
  `convert #{animal['file']} -resize #{pct.round(2)}% /tmp/animal_scaled.png`
  animal['file'] = '/tmp/animal_scaled.png'
  animal['cpts'] = scale_cpts(animal['cpts'], pct)
else
  puts "scaling down celeb..."
  pct = 100 * animal_size/celeb_size

  # do the resize
  `convert #{celeb['file']} -resize #{pct.round(2)}% /tmp/celeb_scaled.png`
  celeb['file'] = '/tmp/celeb_scaled.png'
  celeb['cpts'] = scale_cpts(celeb['cpts'], pct)
end

puts "/tmp:"
puts `ls /tmp`

puts "generating morphs..."

cmd = "./shapemorph2 -c1 \"#{celeb['cpts']}\" -c2 \"#{animal['cpts']}\" -f #{FRAMES} -b transparent #{celeb['file']} #{animal['file']} /tmp/out.gif"
puts cmd
system(cmd)
`convert /tmp/out.gif /tmp/out.png`
`rm -f /tmp/*_scaled.png /tmp/out-1.png /tmp/out-3.png /tmp/out-5.png /tmp/out-7.png /tmp/out-9.png`
`rm -f /tmp/out.gif`
`mogrify -trim +repage /tmp/out-*.png`

puts "making a curve..."

# now lay out on a canvas
pages = (0..FRAMES).to_a.select(&:even?).map do |i|
  x = i * (size.to_f / 10)
  y = Math.log2((i+1)) * size.to_f / 4
  "-page +#{x.round}+#{y.round} /tmp/out-#{i}.png"
end.join(' ')

`convert #{pages} -background transparent -layers mosaic /tmp/curve.png`
`convert /tmp/curve.png -trim +repage -geometry 800x700\\> /tmp/curve.png`

puts "putting it on a background..."
curve_w, curve_h = `identify -format "%w %h" /tmp/curve.png`.split(' ').map(&:to_i)


background = "backgrounds/#{`ls backgrounds`.split(' ').sample}"
bg_w, bg_h = `identify -format "%w %h" #{background}`.split(' ').map(&:to_i)

tint = "#{rand(255)},#{rand(255)},#{rand(255)}"
`convert -colorize #{tint} -geometry #{(curve_w*1.5).round}x#{(curve_h*4).round} logo.png /tmp/logo_scaled.png`


`convert #{background} -colorize #{tint} -geometry #{(curve_w*1.5).round}x#{(curve_h*4).round} /tmp/background_scaled.png`
`composite -gravity NORTH /tmp/logo_scaled.png /tmp/background_scaled.png /tmp/missing_morph.png`

map_x = 10
map_y = `identify -format %h /tmp/logo_scaled.png`.to_i + 10

`composite -geometry '+#{map_x}+#{map_y}' /tmp/curve.png /tmp/missing_morph.png /tmp/cover_image.png`

final_w, final_h = `identify -format '%w %h' /tmp/cover_image.png`.split(' ').map(&:to_f)

title = ['The Automation', 'The Generation', 'The Computerization', 'The Mechanization', 'The Repetition', 'The Electronification', 'The Application'].sample

`convert /tmp/cover_image.png -fill white -undercolor black -font './eurostile_bold.ttf' -pointsize 24 -gravity southeast -annotate -5+100 '#{title}    ' /tmp/missing_author.png`
`convert /tmp/missing_author.png -fill white -undercolor black -font './eurostile_bold.ttf' -pointsize 24 -gravity southeast -annotate -5+30 'C. Kolderup    ' /tmp/animorphs.jpg`

if Options.get(:masto)
  puts "posting to mastodon..."

  begin
    media = mastodon.upload_media(File.new("/tmp/animorphs.jpg"), description: "The cover of a fictional entry in the Animorphs book series titled '#{title}' by author 'C. Kolderup' where #{celeb['name']} transforms into #{animal['name']}")

  rescue StandardError => e
    puts "Exception raised: #{e.inspect}"
    exit
  end

  puts "media id: #{media.id}"
  mastodon.create_status('', media_ids: [media.id])

  puts "done!"
end
