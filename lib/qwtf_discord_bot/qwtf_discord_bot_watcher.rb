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
          redis_key = "#{address}:#{name}"

          unless seen_recently?(redis_key)
            endpoint.channel_ids.each do |channel_id|
              report_joined(
                name: name,
                channel_id: channel_id,
                server_summary: request.server_summary
              )
            end
          end

          update_last_seen_at(redis_key)
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

  def seen_recently?(redis_key)
    redis.get(redis_key)
  end

  def update_last_seen_at(redis_key)
    redis.set(key, Time.now)
    redis.expire(key, TEN_MINUTES)
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
