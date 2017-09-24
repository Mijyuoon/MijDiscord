# frozen_string_literal: true

module MijDiscord::Data
  class Message
    include IDObject

    attr_reader :bot

    attr_reader :content
    alias_method :text, :content
    alias_method :to_s, :content

    attr_reader :author
    alias_method :user, :author

    attr_reader :channel

    attr_reader :timestamp

    attr_reader :edited_timestamp
    alias_method :edit_timestamp, :edited_timestamp

    attr_reader :user_mentions

    attr_reader :role_mentions

    attr_reader :mention_everyone

    attr_reader :attachments

    attr_reader :embeds

    # attr_reader :reactions

    attr_reader :tts
    alias_method :tts?, :tts

    # attr_reader :nonce

    attr_reader :edited
    alias_method :edited?, :edited

    attr_reader :pinned
    alias_method :pinned?, :pinned

    attr_reader :webhook_id

    def initialize(data, bot)
      @bot = bot

      @id = data['id'].to_i
      @channel = @bot.channel(data['channel_id'])

      # @nonce = data['nonce']
      @webhook_id = data['webhook_id']&.to_i

      if (author = data['author'])
        if author['discriminator'] == '0000'
          @author = @bot.cache.put_user(author)
        elsif @channel.private?
          @author = @channel.recipient
        else
          member = @channel.server.member(author['id'])
          @author = member || @bot.user(author['id'])
        end
      end

      update_data(data)
    end

    def update_data(data)
      @content = data.fetch('content', @content)
      @pinned = data.fetch('pinned', @pinned)
      @tts = data.fetch('tts', @tts)

      @timestamp = Time.parse(data['timestamp']).utc if data['timestamp']
      @edited_timestamp = Time.parse(data['edited_timestamp']).utc if data['edited_timestamp']
      @edited = !!@edited_timestamp

      @mention_everyone = !!data['mention_everyone']

      # @reactions = []
      # if (reactions = data['reactions'])
      #   reactions.each {|x| @reactions << Reaction.new(x) }
      # end

      @user_mentions = []
      if (mentions = data['mentions'])
        mentions.each {|x| @user_mentions << @bot.cache.put_user(x) }
      end

      @role_mentions = []
      if @channel.text? && (mentions = data['mention_roles'])
        mentions.each {|x| @role_mentions << @channel.server.role(x) }
      end

      @attachments = []
      if (attachments = data['attachments'])
        attachments.each {|x| @attachments << Attachment.new(x, self) }
      end

      @embeds = []
      if (embeds = data['embeds'])
        embeds.each {|x| @embeds << Embed.new(x) }
      end
    end

    def reply(text: '', embed: nil, tts: false)
      @channel.send_message(text: text, embed: embed, tts: tts)
    end

    def reply_file(file, caption: '', tts: false)
      @channel.send_file(file, caption: caption, tts: tts)
    end

    def edit(text: '', embed: nil)
      response = MijDiscord::Core::API::Channel.edit_message(@bot.token, @channel.id, @id,
        text, [], embed&.to_h)
      @channel.cache.put_message(JSON.parse(response), update: true)
    end

    def pin
      MijDiscord::Core::API::Channel.pin_message(@bot.token, @channel.id, @id)
      nil
    end

    def unpin
      MijDiscord::Core::API::Channel.unpin_message(@bot.token, @channel.id, @id)
      nil
    end

    def webhook?
      !@webhook_id.nil?
    end

    # def my_reactions
    #   @reactions.select(&:me)
    # end

    def create_reaction(reaction)
      emoji = reaction.respond_to?(:reaction) ? reaction.reaction : reaction
      MijDiscord::Core::API::Channel.create_reaction(@bot.token, @channel.id, @id, emoji)
      nil
    end

    alias_method :add_reaction, :create_reaction

    def reacted_with(reaction)
      emoji = reaction.respond_to?(:reaction) ? reaction.reaction : reaction
      response = MijDiscord::Core::API::Channel.get_reactions(@bot.token, @channel.id, @id, emoji)
      JSON.parse(response).map {|x| @bot.cache.put_user(x) }
    end

    def delete_reaction(reaction, user: nil)
      emoji = reaction.respond_to?(:reaction) ? reaction.reaction : reaction
      if user.nil?
        MijDiscord::Core::API::Channel.delete_own_reaction(@bot.token, @channel.id, @id, emoji)
      else
        MijDiscord::Core::API::Channel.delete_user_reaction(@bot.token, @channel.id, @id, emoji, user.to_id)
      end
      nil
    end

    def clear_reactions
      MijDiscord::Core::API::Channel.delete_all_reactions(@bot.token, @channel.id, @id)
      nil
    end

    def delete
      MijDiscord::Core::API::Channel.delete_message(@bot.token, @channel.id, @id)
      nil
    end

    def inspect
      %(<Message id=#{@id} timestamp=#{@timestamp} content="#{@content}" author=#{@author.inspect} channel=#{@channel.inspect}>)
    end
  end

  class Attachment
    attr_reader :message

    attr_reader :url

    attr_reader :proxy_url

    attr_reader :filename

    attr_reader :size

    attr_reader :width

    attr_reader :height

    def initialize(data, message)
      @message = message

      @url, @proxy_url = data['url'], data['proxy_url']
      @filename, @size = data['filename'], data['size']
      @width, @height = data['width'], data['height']
    end

    def image?
      !@width.nil? && !@height.nil?
    end
  end
end