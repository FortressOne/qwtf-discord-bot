require "qwtf_discord_bot/version"
require "discordrb"
require 'active_support/core_ext/string'

require "qstat_request"
require "player"
require "team"
require "emoji"

module QwtfDiscordBot
  ENVIRONMENT_VARIABLES = [
    "QWTF_DISCORD_BOT_TOKEN",
    "QWTF_DISCORD_BOT_CLIENT_ID",
    "QWTF_DISCORD_BOT_CHANNEL_ID"
  ]

  ENVIRONMENT_VARIABLES.each do |env_var|
    raise "#{env_var} environment variable not set" unless ENV[env_var]
  end

  TOKEN = ENV["QWTF_DISCORD_BOT_TOKEN"].strip
  CLIENT_ID = ENV["QWTF_DISCORD_BOT_CLIENT_ID"].strip
  CHANNEL_ID = ENV["QWTF_DISCORD_BOT_CHANNEL_ID"].strip
  HOSTNAME = "fortressone.ga"

  bot = Discordrb::Commands::CommandBot.new(
    token: TOKEN,
    client_id: CLIENT_ID,
    prefix: "!"
  )

  bot.command :server do |event|
    QstatRequest.new(HOSTNAME).output
  end

  # TODO use `bot.ready` handler with a flag to start schedulers
  # or even better run in a seperate process
  bot.run :async

  THIRTY_SECONDS = 30
  TEN_MINUTES = 10 * 60

  history = {}

  every(THIRTY_SECONDS) do
    request = QstatRequest.new(HOSTNAME)
    players = request.players
    numplayers = request.numplayers

    players.each do |player|
      report_joined(player, numplayers) unless seen_recently?(player, history)
      history[player] = Time.now
    end
  end

  private

    def report_joined(player, numplayers)
      number_of_other_players = numplayers - 1

      bot.send_message(
        QWTF_DISCORD_BOT_CHANNEL_ID,
        "*#{player}* has joined #{number_of_other_players} " \
        "#{"other player".pluralize(number_of_other_players)} on *#{HOSTNAME}*"
      )
    end

    def seen_recently?(player, history)
      last_seen = history[player]
      last_seen && (Time.now - last_seen > TEN_MINUTES)
    end

    def every(n)
      loop do
        before = Time.now
        yield
        interval = n-(Time.now-before)
        sleep(interval) if interval > 0
      end
    end
end
