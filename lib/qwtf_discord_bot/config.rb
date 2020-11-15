require 'endpoint'
require 'dashboard'

class Config
  def initialize(config)
    @config = YAML.load_file(config)
  end

  def token
    @token ||= @config['token']
  end

  def client_id
    @client_id ||= @config['client_id']
  end

  def endpoints
    @endpoints ||= @config['endpoints'].map do |endpoint|
      Endpoint.new(endpoint)
    end
  end

  def dashboards
    @dashboards ||= @config['dashboards']
  end

  def emojis
    @emojis ||= @config['emojis']
  end
end
