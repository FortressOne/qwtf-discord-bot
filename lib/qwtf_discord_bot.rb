require 'qwtf_discord_bot/version'
require 'qwtf_discord_bot/qwtf_discord_bot_server'
require 'qwtf_discord_bot/qwtf_discord_bot_watcher'
require 'discordrb'
require 'yaml'

require 'config'
require 'qstat_request'
require 'player'
require 'team'
require 'emoji'
require 'roster'

class QwtfDiscordBot # :nodoc:
  CONFIG_FILE = ENV['QWTF_DISCORD_BOT_CONFIG_FILE'] || "#{Dir.pwd}/config.yaml"

  def initialize
    @config = Config.new(CONFIG_FILE)
    @token = @config.token
    @client_id = @config.client_id
    @endpoints = @config.endpoints
  end
end
