require 'mastodon'

class MastodonPost
  def initialize(instance_url, bearer_token)
    @mastodon = Mastodon::REST::Client.new(base_url: instance_url, bearer_token: bearer_token)
  end

  def submit(text, image_array, caption_array)

    media = []
    image_array.each_with_index do |image, i|
      begin
        media << mastodon.upload_media(File.new(image), description: caption_array[i])
      rescue StandardError => e
        puts "Exception raised: #{e.inspect}"
      end
    end

    mastodon.create_status(text, media_ids: media.map(&:id))
  end
