class EventDecorator
  NOTIFY_ROLES = {
    813663438994669590  => "<@&812486174156390400>",  # @trueskill bot
    513699536846323712  => "<@&533995292975038479>",  # @europe
    504171613793681408  => "<@&522695282887229440>",  # @north-america
    542237808895459338  => "<@&427655970177548288>",  # @oceania
    593421408558645258  => "<@&543039259133739028>",  # @asia
    531050292003995648  => "<@&531050407246561280>",  # @brazil
    1149027296250953809 => "<@&1305974891929010236>"  # @quad
  }

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
    NOTIFY_ROLES[channel_id]
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
