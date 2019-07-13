class Endpoint
  def initialize(config)
    @config = config
  end

  def address
    @config.keys.first
  end

  def channel_ids
    channel_ids = []

    @config.values.each do |settings|
      settings.each do |setting|
        setting["channel_ids"].each do |channel_id|
          channel_ids << channel_id
        end
      end
    end

    channel_ids
  end
end
