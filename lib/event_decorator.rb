class EventDecorator
  attr_accessor :event

  def initialize(event)
    @event = event
  end

  def channel
    @event.channel
  end

  def channel_id
    @event.channel.id
  end

  def display_name
    user.display_name
  end

  def user_id
    user.id
  end

  def mention
    user.mention
  end

  def users
    server.users
  end

  def mention_for(user_id)
    find_user(user_id)&.mention
  end

  def mentions_for(user_ids)
    find_users(user_ids).map(&:mention)
  end

  def display_name_for(user_id)
    find_user(user_id)&.display_name
  end

  def display_names_for(user_ids)
    find_users(user_ids).map(&:display_name)
  end

  def user
    @event.user
  end

  def find_user(user_id)
    users.find { |user| user.id == user_id }
  end

  def notify_roles
    case channel_id
    when 813663438994669590 then "@trueskill bot"
    when 513699536846323712 then "@europe"
    when 504171613793681408 then "@north-america"
    when 542237808895459338 then "@oceania"
    when 593421408558645258 then "@asia"
    when 531050292003995648 then "@south-america"
    else
      "@here"
    end
  end

  def find_users(user_ids)
    user_ids.map do |user_id|
      find_user(user_id)
    end
  end

  private

  def server
    @event.server
  end
end
