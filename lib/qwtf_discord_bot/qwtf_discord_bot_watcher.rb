class QwtfDiscordBotWatcher < QwtfDiscordBot
  THIRTY_SECONDS = 30
  TEN_MINUTES = 10 * 60

  def run
    every(THIRTY_SECONDS) do
      request = QstatRequest.new(endpoint)

      if request.players
        player_names = request.players.map(&:name)

        player_names.each do |name|
          unless seen_recently?(name)
            report_joined(name: name, server_summary: request.server_summary)
          end

          history[name] = Time.now
        end
      end
    end
  end

  def every(n_seconds)
    loop do
      before = Time.now
      yield
      interval = n_seconds - (Time.now - before)
      sleep(interval) if interval > 0
    end
  end

  def seen_recently?(name)
    last_seen = history[name]
    last_seen && (Time.now - last_seen < TEN_MINUTES)
  end

  def report_joined(name:, server_summary:)
    Discordrb::API::Channel.create_message(
      "Bot #{TOKEN}",
      CHANNEL_ID,
      "#{name} has joined #{server_summary}"
    )
  end

  def history
    @history ||= {}
  end
end
