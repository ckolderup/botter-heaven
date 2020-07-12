require 'dotenv'

Dotenv.load

module Env
  def self.[](arg)
    if ENV['GITHUB_ACTIONS']
      ENV["#{File.basename(Dir.pwd).upcase}_#{arg}"]
    else
      ENV[arg]
    end
  end
end
