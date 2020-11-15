class QwtfDiscordBotDashboard
  THIRTY_SECONDS = 30

  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      help_command: false,
      prefix: proc do |message|
        match = /^\!(\w+)(.*)/.match(message.content)
        if match
          first = match[1]
          rest = match[2]
          # Return the modified string with the first word lowercase:
          "#{first.downcase}#{rest}"
        end
      end
    )

    @dashboards ||= QwtfDiscordBot.config.dashboards.map do |channel|
      Dashboard.new(channel, bot)
    end

    every(THIRTY_SECONDS) do
      @dashboards.each do |dashboard|
        dashboard.update
      end
    end
  end

  private

  def every(n_seconds)
    loop do
      before = Time.now
      yield
      interval = n_seconds - (Time.now - before)
      sleep(interval) if interval > 0
    end
  end
end
