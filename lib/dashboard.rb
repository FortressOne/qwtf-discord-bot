class Dashboard
  def initialize(dashboard_config, bot)
    @server = bot.server(dashboard_config["server_id"])
    @endpoints = dashboard_config["endpoints"]
    @messages = {}

    old_dashboard_channel = @server.channels.find do |chan|
      chan.name == dashboard_config["name"] && chan.topic = "QWTF Bot Dashboard"
    end

    old_dashboard_channel && old_dashboard_channel.delete

    @channel = @server.create_channel(dashboard_config["name"])
    @channel.topic = "QWTF Bot Dashboard"
    @channel.position = dashboard_config["position"]
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
