require "qwtf_discord_bot/version"
require "discordrb"

require "qstat_request"
require "player"
require "team"
require "emoji"

module QwtfDiscordBot
  ENVIRONMENT_VARIABLES = ["QWTF_DISCORD_BOT_TOKEN", "QWTF_DISCORD_BOT_CLIENT_ID"]

  ENVIRONMENT_VARIABLES.each do |env_var|
    raise "#{env_var} environment variable not set" unless ENV[env_var]
  end

  TOKEN = ENV["QWTF_DISCORD_BOT_TOKEN"].strip
  CLIENT_ID = ENV["QWTF_DISCORD_BOT_CLIENT_ID"].strip
  HOSTNAME = "fortressone.ga"

  bot = Discordrb::Commands::CommandBot.new token: TOKEN, client_id: CLIENT_ID, prefix: "!"

  bot.command :server do |event|
    QstatRequest.new(HOSTNAME).output
  end

  bot.run
end
