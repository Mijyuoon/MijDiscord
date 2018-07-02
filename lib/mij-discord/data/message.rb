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

    attr_reader :reactions

    attr_reader :tts
    alias_method :tts?, :tts

    attr_reader :nonce

    attr_reader :edited
    alias_method :edited?, :edited

    attr_reader :pinned
    alias_method :pinned?, :pinned

    attr_reader :webhook_id

    def initialize(data, bot)
      @bot = bot

      data = data.first if data.is_a?(Array)

      @id = data['id'].to_i
      @channel = @bot.channel(data['channel_id'])

      @nonce = data['nonce']
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

      @reactions = []
      if (reactions = data['reactions'])
        reactions.each {|x| @reactions << Reaction.new(x, self) }
      end

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

    def update_reaction(add: nil, remove: nil, clear: false)
      @reactions.clear if clear

      unless add.nil?
        id = add['emoji']['id'].to_i
        name = add['emoji']['name']
        userid = add['user_id'].to_i

        if (emoji = @reactions.find {|x| id.zero? ? (x.name == name) : (x.id == id) })
          emoji.update_data(count: emoji.count + 1, me: @bot.profile == userid ? true : nil)
        else
          emoji = Reaction.new(add, self)
          emoji.update_data(me: @bot.profile == userid)
          @reactions << emoji
        end
      end

      unless remove.nil?
        id = remove['emoji']['id'].to_i
        name = remove['emoji']['name']
        userid = remove['user_id'].to_i

        if (emoji = @reactions.find {|x| id.zero? ? (x.name == name) : (x.id == id) })
          emoji.update_data(count: emoji.count - 1, me: @bot.profile == userid ? false : nil)
          @reactions.delete(emoji) if emoji.count < 1
        else
          # WTF? How did this happen?
          MijDiscord::LOGGER.warn('Events') { 'MESSAGE_REACTION_REMOVE triggered on message with no reactions!' }
        end
      end
    end

    def reply(text: '', embed: nil, tts: false)
      @channel.send_message(text: text, embed: embed, tts: tts)
    end

    def reply_file(file, caption: '', tts: false)
      @channel.send_file(file, caption: caption, tts: tts)
    end

    def edit(text: '', embed: nil)
      raise MijDiscord::Errors::MessageTooLong if text.length > 2000

      embed = case embed
        when nil then nil
        when Hash
          MijDiscord::Data::Embed.construct(embed)
        when MijDiscord::Data::Embed then embed
        else raise ArgumentError, 'Invalid embed'
      end&.to_hash

      response = MijDiscord::Core::API::Channel.edit_message(@bot.auth, @channel.id, @id, text, [], embed)
      @channel.cache.put_message(JSON.parse(response), update: true)
    end

    def pin
      MijDiscord::Core::API::Channel.pin_message(@bot.auth, @channel.id, @id)
      nil
    end

    def unpin
      MijDiscord::Core::API::Channel.unpin_message(@bot.auth, @channel.id, @id)
      nil
    end

    def webhook?
      !@webhook_id.nil?
    end

    def my_reactions
      @reactions.select(&:me)
    end

    def create_reaction(reaction)
      emoji = reaction.respond_to?(:reaction) ? reaction.reaction : reaction
      MijDiscord::Core::API::Channel.create_reaction(@bot.auth, @channel.id, @id, emoji)
      nil
    end

    alias_method :add_reaction, :create_reaction

    def reacted_with(reaction)
      emoji = reaction.respond_to?(:reaction) ? reaction.reaction : reaction
      response = MijDiscord::Core::API::Channel.get_reactions(@bot.auth, @channel.id, @id, emoji)
      JSON.parse(response).map {|x| @bot.cache.put_user(x) }
    end

    def delete_reaction(reaction, user: nil)
      emoji = reaction.respond_to?(:reaction) ? reaction.reaction : reaction
      if user.nil?
        MijDiscord::Core::API::Channel.delete_own_reaction(@bot.auth, @channel.id, @id, emoji)
      else
        MijDiscord::Core::API::Channel.delete_user_reaction(@bot.auth, @channel.id, @id, emoji, user.to_id)
      end
      nil
    end

    def clear_reactions
      MijDiscord::Core::API::Channel.delete_all_reactions(@bot.auth, @channel.id, @id)
      nil
    end

    def delete
      MijDiscord::Core::API::Channel.delete_message(@bot.auth, @channel.id, @id)
      nil
    end

    def inspect
      MijDiscord.make_inspect(self,
        :id, :content, :author, :channel, :timestamp, :edited, :pinned, :edited_timestamp,
        :user_mentions, :role_mentions, :attachments, :embeds, :tts, :webhook_id)
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

    def inspect
      MijDiscord.make_inspect(self, :url, :filename, :size, :width, :height)
    end
  end
end