require 'qwtf_discord_bot/version'
require 'qwtf_discord_bot/qwtf_discord_bot_server'
require 'qwtf_discord_bot/qwtf_discord_bot_pug'
require 'qwtf_discord_bot/qwtf_discord_bot_watcher'
require 'qwtf_discord_bot/config'
require 'discordrb'
require 'yaml'

require 'qstat_request'
require 'player'
require 'team'
require 'emoji'
require 'roster'

module QwtfDiscordBot # :nodoc:
  CONFIG_FILE = ENV['QWTF_DISCORD_BOT_CONFIG_FILE'] || "#{Dir.pwd}/config.yaml"

  def self.config
    @config ||= Config.new(CONFIG_FILE)
  end
end
