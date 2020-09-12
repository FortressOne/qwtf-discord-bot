require 'qwtf_discord_bot/version'
require 'qwtf_discord_bot/qwtf_discord_bot_server'
require 'qwtf_discord_bot/qwtf_discord_bot_pug'
require 'qwtf_discord_bot/qwtf_discord_bot_watcher'
require 'qwtf_discord_bot/config'
require 'discordrb'
require 'yaml'
require 'redis'

require 'qstat_request'
require 'player'
require 'team'
require 'emoji'
require 'roster'

module QwtfDiscordBot # :nodoc:
  def self.config
    @config ||= Config.new(config_file)
  end

  def self.config_file
    return ENV['QWTF_DISCORD_BOT_CONFIG_FILE'] if ENV['QWTF_DISCORD_BOT_CONFIG_FILE']
    return "#{Dir.pwd}/config.yaml" if FileTest.exist?("#{Dir.pwd}/config.yaml")

    "#{Dir.home}/.config/qwtf_discord_bot/config.yaml"
  end

  def redis
    Redis.current
  end
end
