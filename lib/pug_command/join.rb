module PugCommand
  class Join
    def initialize(event)
      @event = event
    end

    def call
      setup_pug(event) do |e, pug|
        if pug.joined?(e.user_id)
          return send_embedded_message(
            description: "You've already joined",
            channel: e.channel
          )
        end

        join_pug(e, pug)
        start_pug(pug, e) if pug.has_exactly_maxplayers?
      end
    end
  end

  private

  def setup_pug(event)
    e = EventDecorator.new(event)
    pug = Pug.for(e.channel_id)
    yield(e, pug)
    nil # stop discordrb printing return value
  end
end
