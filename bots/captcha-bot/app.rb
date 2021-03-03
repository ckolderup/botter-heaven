require 'twitter'
require 'discordrb/webhooks'

require_relative '../../lib/options'
require_relative '../../lib/mastodon'
require_relative '../../lib/env'

Options.read

class Captcha
  def self.run
    begin
      tries ||= 5

      commands = ['./script-sliced.sh', './script-mosaic.sh']
      `#{commands.sample}`

      post('result.png')
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
    MastodonPost.new('https://botsin.space', Env['MASTO_ACCESS_TOKEN'])
  end

  def self.post(image_path)
    if Options.get(:discord)
      client = Discordrb::Webhooks::Client.new(url: Env['DISCORD_WEBHOOK_URL'])
      client.execute do |builder|
        builder.file = File.new(image_path)
      end
    end

    if Options.get(:twitter)
      client = twitter_client
      client.update_with_media('', File.new(image_path))
    end

    if Options.get(:masto)
      mastodon = masto_client
      mastodon.submit(
        '',
        [File.new(image_path)],
        ['']
      )
    end
  end
end

Captcha.run
