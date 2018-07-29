require "qwtf_discord_bot/version"
require "discordrb"

require "qstat_request"
require "player"
require "team"
require "emoji"

require "pry"

module QwtfDiscordBot
  raise "DISCORD_QSTAT_BOT_TOKEN environment variable not set" unless ENV["DISCORD_QSTAT_BOT_TOKEN"]

  TOKEN = ENV["DISCORD_QSTAT_BOT_TOKEN"].strip
  CLIENT_ID = ENV["DISCORD_CLIENT_ID"].strip
  HOSTNAME = "fortressone.ga"

  bot = Discordrb::Commands::CommandBot.new token: TOKEN, client_id: CLIENT_ID, prefix: "!"

  bot.command :server do |event|
    QstatRequest.new(HOSTNAME).output
  end

  bot.run
end
