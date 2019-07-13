class Emoji
  def self.for(team:, player_class:)
    emojis = QwtfDiscordBot.config.emojis
    emojis[team] && emojis[team][player_class]
  end
end
