class Dashboard
  def initialize(channel)
    @channel_id = channel["id"]
    @endpoints = channel["endpoints"]
  end

  def update
    if @msg
      @msg.edit(Time.now.to_s)
    else
      @msg ||= Discordrb::API::Channel.create_message(
        "Bot #{QwtfDiscordBot.config.token}",
        @channel_id,
        Time.now.to_s
      )
    end
  end
end
