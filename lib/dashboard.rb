class Dashboard
  def initialize(dashboard_config, bot)
    @server = bot.server(dashboard_config["server_id"])
    @endpoints = dashboard_config["endpoints"]
    @messages = {}


    channel_name = dashboard_config["name"]

    old_dashboard_channel = @server.channels.find do |chan|
      chan.name == channel_name
    end

    @channel = if old_dashboard_channel
                 old_messages = JSON.parse(
                   Discordrb::API::Channel.messages(
                     "Bot #{QwtfDiscordBot.config.token}",
                     old_dashboard_channel.id,
                     100
                   )
                 )

                 old_messages.each do |old_message|
                   sleep 2
                   old_dashboard_channel.message(old_message['id']).delete
                 end

                 old_dashboard_channel
               else
                 @server.create_channel(channel_name).tap do |channel|
                   channel.topic = "QWTF Bot Dashboard"
                 end
               end
  end

  def update
    @endpoints.each do |endpoint|
      qstat_request = QstatRequest.new(endpoint)

      if qstat_request.is_empty?
        if @messages[endpoint]
          @messages[endpoint].delete
          @messages.delete(endpoint)
        end

        next
      end

      embed = qstat_request.to_full_embed

      @messages[endpoint] = if @messages[endpoint]
                              @messages[endpoint].edit(nil, embed)
                            else
                              @channel.send_embed(nil, embed)
                            end
    end
  end
end
