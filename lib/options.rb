require 'optparse'

module Options
  @options = {}

  def self.read
    ::OptionParser.new do |opts|
      opts.banner = "Usage: app.rb [options]"

      opts.on("-t", "--tweet", "--twitter", "Post to Twitter") do |t|
        @options[:twitter] = true
      end

      opts.on("-m", "--masto", "Post to Mastodon") do |m|
        @options[:masto] = true
      end

      opts.on("-d", "--discord", "Post to Discord") do |d|
        @options[:discord] = true
      end

      opts.on("-x", "--test", "Post to private Discord test channel") do |x|
        @options[:discord_test] = true
      end
    end.parse!
  end

  def self.get(sym)
    @options[sym]
  end

  def self.set(sym, val)
    @options[sym] = val
  end
end
