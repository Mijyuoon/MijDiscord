# frozen_string_literal: true

module MijDiscord::Data
  class Application
    include IDObject

    attr_reader :name

    attr_reader :description

    attr_reader :rpc_origins

    attr_reader :flags

    attr_reader :owner

    def initialize(data, bot)
      @bot = bot

      @id = data['id'].to_i
      @name = data['name']
      @description = data['description']
      @icon_id = data['icon']
      @rpc_origins = data['rpc_origins']
      @flags = data['flags']
      @owner = @bot.cache.put_user(data['owner'])
    end

    def icon_url(format = nil)
      return nil if @icon_id.nil?
      MijDiscord::Core::API.app_icon_url(@id, @icon_id, format)
    end

    def inspect
      %(<Application id=#{@id} name="#{@name}">)
    end
  end
end