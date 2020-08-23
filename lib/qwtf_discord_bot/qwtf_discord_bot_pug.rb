require 'event_wrapper'

class QwtfDiscordBotPug
  include QwtfDiscordBot

  FOUR_HOURS = 4 * 60 * 60

  def run
    bot = Discordrb::Commands::CommandBot.new(
      token: QwtfDiscordBot.config.token,
      client_id: QwtfDiscordBot.config.client_id,
      help_command: false,
      prefix: '!'
    )

    bot.command :join do |event, *args|
      e = EventWrapper.new(event)

      redis.setnx(e.pug_key, Time.now)
      redis.sadd(e.players_key, e.user_id)

      message = if e.joined_player_count == e.maxplayers
                  mentions = joined_users(e).map do |user|
                    user.mention
                  end
                  "Time to play! #{mentions.join(" ")}"
                elsif (e.joined_player_count == 1)
                  [
                    "#{e.username} creates a PUG",
                    e.player_slots,
                    e.role,
                  ].join(" | ")
                elsif e.slots_left <= 3
                  [
                    "#{e.username} joins the PUG",
                    e.player_slots,
                    "#{e.slots_left} more",
                    e.role,
                  ].join(" | ")
                else
                  [
                    "#{e.username} joins the PUG",
                    e.player_slots,
                  ].join(" | ")
                end

      send_and_log_message(message, event)
    end

    bot.command :status do |event, *args|
      e = EventWrapper.new(event)
      usernames = joined_users(e).map(&:username)

      message = if e.pug_active?
                  [
                    "#{usernames.join(", ")} joined",
                    e.player_slots
                  ].join(" | ")
                else
                  "No PUG has been started. `!join` to create"
                end

      send_and_log_message(message, event)
    end

    bot.command :maxplayers do |event, *args|
      e = EventWrapper.new(event)
      new_maxplayers = args[0]

      message = if new_maxplayers
        redis.set(e.maxplayers_key, new_maxplayers)
        "Max number of players set to #{e.maxplayers} | #{e.player_slots}"
      else
        "Current max number of players is #{e.maxplayers} | #{e.player_slots}"
      end

      send_and_log_message(message, event)

      if e.joined_player_count >= e.maxplayers
        mentions = joined_users(e).map do |user|
          user.mention
        end

        message = "Time to play! #{mentions.join(" ")}"
        send_and_log_message(message, event)
      end
    end

    bot.command :leave do |event, *args|
      e = EventWrapper.new(event)

      redis.srem(e.players_key, e.user_id)

      message = "#{e.username} leaves the PUG | #{e.player_slots}"

      send_and_log_message(message, event)

      if e.joined_player_count == 0
        redis.del(e.pug_key)

        message = "PUG ended"
        send_and_log_message(message, event)
      end
    end

    bot.command :end do |event, *args|
      e = EventWrapper.new(event)

      redis.del(e.pug_key)
      redis.del(e.players_key)

      message = "PUG ended"
      send_and_log_message(message, event)
    end

    bot.command :role do |event, *args|
      e = EventWrapper.new(event)
      role = args[0]

      redis.set(e.role_key, role)

      message = "Notification role set to #{role}"
      send_and_log_message(message, event)
    end

    bot.run
  end

  private

  def send_and_log_message(message, event)
    event.channel.send_message(message)
    puts message
  end

  def joined_users(event)
    redis.smembers(event.players_key).map do |user_id|
      event.users.find do |user|
        user.id.to_s == user_id
      end
    end
  end
end
