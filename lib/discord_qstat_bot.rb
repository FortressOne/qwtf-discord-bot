require "discord_qstat_bot/version"
require "discordrb"

require "pry"
require "qstat_request"
require "player"
require "team"
require "teams"
require "emoji"

class DiscordQstatBot::Server
	raise "Set DISCORD_QSTAT_BOT_TOKEN environment variable" unless ENV["DISCORD_QSTAT_BOT_TOKEN"]
	TOKEN = ENV["DISCORD_QSTAT_BOT_TOKEN"].strip
	HOSTNAME = "qwtf.ga"

	def self.run
		raise "DISCORD_QSTAT_BOT_TOKEN environment variable not set" unless ENV["DISCORD_QSTAT_BOT_TOKEN"]

		Teams.build

		bot = Discordrb::Commands::CommandBot.new token: TOKEN, prefix: "!"

		bot.command :server do |event|
			QstatRequest.new(HOSTNAME).output
		end

		bot.run
	end
end
