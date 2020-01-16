require "redis"

class QwtfDiscordBotWatcher
  include QwtfDiscordBot

  THIRTY_SECONDS = 30
  TEN_MINUTES = 10 * 60

  def run
    every(THIRTY_SECONDS) do
      QwtfDiscordBot.config.endpoints.each do |endpoint|
        address = endpoint.address
        request = QstatRequest.new(address)
        next if request.is_empty?

        request.player_names.each do |name|
          unless seen_recently?(endpoint: address, name: name)
            endpoint.channel_ids.each do |channel_id|
              report_joined(
                name: name,
                channel_id: channel_id,
                server_summary: request.server_summary
              )
            end
          end

          redis.set("#{address}:#{name}", Time.now)
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

  def seen_recently?(endpoint:, name:)
    last_seen = redis.get("#{endpoint}:#{name}")
    last_seen && (Time.now - Time.parse(last_seen) < TEN_MINUTES)
  end

  def report_joined(name:, channel_id:, server_summary:)
    Discordrb::API::Channel.create_message(
      "Bot #{QwtfDiscordBot.config.token}",
      channel_id,
      "#{name} has joined #{server_summary}"
    )
  end

  private

  def redis
    @redis ||= Redis.new
  end
end
