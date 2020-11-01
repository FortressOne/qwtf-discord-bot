class QwtfDiscordBotDashboard
  THIRTY_SECONDS = 5

  def run
    every(THIRTY_SECONDS) do
      QwtfDiscordBot.config.dashboards.each do |dashboard|
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
