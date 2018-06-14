require "discord_qstat_bot/version"
require "discordrb"

require "qstat_request"
require "player"
require "team"
require "emoji"

require "pry"

module DiscordQstatBot
	raise "DISCORD_QSTAT_BOT_TOKEN environment variable not set" unless ENV["DISCORD_QSTAT_BOT_TOKEN"]

	TOKEN = ENV["DISCORD_QSTAT_BOT_TOKEN"].strip
	HOSTNAME = "qwtf.ga"

	bot = Discordrb::Commands::CommandBot.new token: TOKEN, prefix: "!"

	bot.command :server do |event|
		QstatRequest.new(HOSTNAME).output
	end

	bot.run
end
