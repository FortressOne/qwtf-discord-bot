require 'pug'

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

    bot.command :join do |event, *_args|
      pug = Pug.for(event.channel.id)
      user = event.user
      username = user.username
      user_id = user.id

      pug.join(user_id)

      return start_pug(event, pug) if pug.full?

      message = if (pug.joined_player_count == 1)
                  [
                    "#{username} creates a PUG",
                    pug.player_slots,
                    pug.role,
                  ].join(" | ")
                elsif pug.slots_left <= 3
                  [
                    "#{username} joins the PUG",
                    pug.player_slots,
                    "#{pug.slots_left} more",
                    pug.role,
                  ].join(" | ")
                else
                  [
                    "#{username} joins the PUG",
                    pug.player_slots,
                  ].join(" | ")
                end

      send_and_log_message(message, event)
    end

    bot.command :status do |event, *args|
      pug = Pug.for(event.channel.id)

      message = if pug.active?
                  [
                    "#{usernames(event, pug.joined_players).join(" ")} joined",
                    pug.player_slots
                  ].join(" | ")
                else
                  "No PUG has been started. `!join` to create"
                end

      send_and_log_message(message, event)
    end

    bot.command :maxplayers do |event, *args|
      pug = Pug.for(event.channel.id)
      new_maxplayers = args[0]

      message = if new_maxplayers
        pug.maxplayers = new_maxplayers
        "Max number of players set to #{pug.maxplayers} | #{pug.player_slots}"
      else
        "Current max number of players is #{pug.maxplayers} | #{pug.player_slots}"
      end

      send_and_log_message(message, event)

      start_pug(event, pug) if pug.full?
    end

    bot.command :leave do |event, *_args|
      pug = Pug.for(event.channel.id)
      user = event.user
      username = user.username
      user_id = user.id

      pug.leave(user_id)

      message = "#{username} leaves the PUG | #{pug.player_slots} remain"

      send_and_log_message(message, event)

      if pug.empty?
        pug.end_pug

        message = "PUG ended"
        send_and_log_message(message, event)
      end
    end

    bot.command :end do |event, *_args|
      pug = Pug.for(event.channel.id)
      pug.end_pug

      message = "PUG ended"
      send_and_log_message(message, event)
    end

    bot.command :role do |event, *args|
      pug = Pug.for(event.channel.id)
      role = args.join(" ")
      pug.role = role

      message = "Notification role set to #{role}"
      send_and_log_message(message, event)
    end

    bot.run
  end

  private

  def start_pug(event, pug)
    message = [
      "Time to play!",
      pug.player_slots,
      mentions(event, pug.joined_players).join(" "),
    ].join(" | ")

    send_and_log_message(message, event)
  end

  def usernames(event, player_ids)
    player_ids.map do |player_id|
      find_user(event, player_id).username
    end
  end

  def mentions(event, player_ids)
    player_ids.map do |player_id|
      find_user(event, player_id).mention
    end
  end

  def find_user(event, user_id)
    event.server.users.find { |user| user.id == user_id }
  end

  def send_and_log_message(message, event)
    event.channel.send_message(message)
    puts message
  end
end
