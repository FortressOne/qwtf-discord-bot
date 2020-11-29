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
      position = old_dashboard_channel.position
      topic = old_dashboard_channel.topic
      category = old_dashboard_channel.category
      old_dashboard_channel.delete

      @server.create_channel(channel_name).tap do |channel|
        channel.position = position
        channel.topic = topic if topic
        channel.category = category if category
      end
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
