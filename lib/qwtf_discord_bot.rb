require 'qwtf_discord_bot/version'
require 'qwtf_discord_bot/qwtf_discord_bot_server'
require 'qwtf_discord_bot/qwtf_discord_bot_watcher'
require 'discordrb'

require 'qstat_request'
require 'player'
require 'team'
require 'emoji'
require 'roster'

class QwtfDiscordBot
  ENV_VARS = [
    'QWTF_DISCORD_BOT_TOKEN',
    'QWTF_DISCORD_BOT_CLIENT_ID',
    'QWTF_DISCORD_BOT_CHANNEL_ID'
  ]

  if ENV_VARS.any? { |var| !ENV.key?(var) }
    raise "Environment variables not configured"
  end

  TOKEN = ENV['QWTF_DISCORD_BOT_TOKEN'].strip
  CLIENT_ID = ENV['QWTF_DISCORD_BOT_CLIENT_ID'].strip
  CHANNEL_ID = ENV['QWTF_DISCORD_BOT_CHANNEL_ID'].strip

  def initialize(hostname:, port:)
    @hostname = hostname
    @port = port
  end

  def endpoint
    @endpoint ||= begin
                    return @hostname if @port == 27500
                    [@hostname, @port].join(':')
                  end
  end
end
