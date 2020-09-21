class EventDecorator
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

  private

  def find_users(user_ids)
    user_ids.map do |user_id|
      find_user(user_id)
    end
  end

  def find_user(user_id)
    users.find { |user| user.id == user_id }
  end

  def server
    @event.server
  end

  def user
    @event.user
  end
end
