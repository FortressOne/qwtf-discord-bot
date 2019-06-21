require 'qwtf_discord_bot/version'
require 'qwtf_discord_bot/qwtf_discord_bot_server'
require 'qwtf_discord_bot/qwtf_discord_bot_watcher'
require 'discordrb'
require 'yaml'

require 'qstat_request'
require 'player'
require 'team'
require 'emoji'
require 'roster'

class QwtfDiscordBot # :nodoc:
  ENV_VARS = %w[
    QWTF_DISCORD_BOT_TOKEN
    QWTF_DISCORD_BOT_CLIENT_ID
    QWTF_DISCORD_BOT_CONFIG_FILE
  ].freeze


  if ENV_VARS.any? { |var| !ENV.key?(var) }
    raise 'Environment variables not configured'
  end

  TOKEN = ENV['QWTF_DISCORD_BOT_TOKEN'].strip
  CLIENT_ID = ENV['QWTF_DISCORD_BOT_CLIENT_ID'].strip
  CONFIG_FILE = ENV['QWTF_DISCORD_BOT_CONFIG_FILE'].strip

  def initialize
    @endpoints = YAML.load_file(CONFIG_FILE)
  end
end
