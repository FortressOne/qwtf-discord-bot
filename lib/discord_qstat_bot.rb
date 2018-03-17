require "discord_qstat_bot/version"
require "discordrb"

class QstatRequest
  attr_reader :status

  def initialize
    @result = JSON.parse(%x[qstat -json -P -qws qwtf.ga]).first
  end

  def address
    @result["address"]
  end

  def map
    @result["map"]
  end

  def numplayers
    @result["numplayers"]
  end

  def maxplayers
    @result["maxplayers"]
  end

  def player_table
    players.map do |player|
      "#{player.emoji}#{player.name}"
    end
  end

  def players
    @result["players"].map do |player|
      Player.new player
    end
  end
end

class Player
  CLASSES = {
    "scout" => "<:tf_scout:424097703127941130>",
    "sniper" => "<:tf_sniper:424097704076115978>",
    "soldier" => "<:tf_soldier:424097704197619712>",
    "demoman" => "<:tf_demoman:424097687739301919>",
    "medic" => "<:tf_medic:424097695418941451>",
    "pyro" => "<:tf_pyro:424097704403271691>",
    "hwguy" => "<:tf_hwguy:424097694030757889>",
    "spy" => "<:tf_spy:424097704138899466>",
    "engineer" => "<:tf_engineer:424097694680612864>"
  } 

  def initialize(hash)
    @player = hash
  end

  def name
    @player["name"]
  end

  def skin
    @player["skin"]
  end

  def klass
    ary = CLASSES.keys.select do |key|
      key[0..2] == short_class_name
    end
    ary.first
  end

  def emoji
    CLASSES[klass]
  end

  private

  def short_class_name
    skin.split("_").last
  end
end

module DiscordQstatBot
  raise "DISCORD_QSTAT_BOT_TOKEN environment variable not set" unless ENV["DISCORD_QSTAT_BOT_TOKEN"]
  TOKEN = ENV["DISCORD_QSTAT_BOT_TOKEN"].strip

  bot = Discordrb::Commands::CommandBot.new token: TOKEN, prefix: "!"

  bot.command :server do |event|
    request = QstatRequest.new

    <<~HEREDOC
      **#{request.address} | #{request.map} | #{request.numplayers}/#{request.maxplayers}**
      #{request.player_table.join "\n"}
    HEREDOC
  end

  bot.run
end
