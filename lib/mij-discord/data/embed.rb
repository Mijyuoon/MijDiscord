# frozen_string_literal: true

module MijDiscord::Data
  class Embed
    attr_reader :type

    attr_reader :title

    attr_reader :description

    attr_reader :url

    attr_reader :timestamp

    attr_reader :color

    attr_reader :footer

    attr_reader :thumbnail

    attr_reader :image

    attr_reader :video

    attr_reader :provider

    attr_reader :author

    attr_reader :fields

    def initialize(data)
      @type, @url = data['type'], data['url']
      @title, @description = data['title'], data['description']

      @color = ColorRGB.new(data['color']) if data['color']
      @timestamp = Time.parse(data['timestamp']).utc if data['timestamp']

      @footer = EmbedFooter.new(data['footer']) if data['footer']
      @thumbnail = EmbedMedia.new(data['thumbnail']) if data['thumbnail']

      @image = EmbedMedia.new(data['image']) if data['image']
      @video = EmbedMedia.new(data['video']) if data['video']

      @author = EmbedAuthor.new(data['author']) if data['author']
      @provider = EmbedProvider.new(data['provider']) if data['provider']

      @fields = data['fields']&.map {|x| EmbedField.new(x) }
    end

    def to_hash
      self.class.construct({
        type: @type,
        title: @title,
        description: @description,
        url: @url,

        color: @color,
        timestamp: @timestamp,

        footer: @footer,
        thumbnail: @thumbnail,

        image: @image,
        video: @video,

        author: @author,
        provider: @provider,

        fields: @fields,
      })
    end

    def self.construct(data)
      embed = {
        type: data[:type] || :rich,
        title: data[:title],
        description: data[:description],
        url: data[:url],

        color: data[:color]&.to_i,
        timestamp: data[:timestamp]&.iso8601,

        footer: data[:footer]&.to_hash,
        thumbnail: data[:thumbnail]&.to_hash,

        image: data[:image]&.to_hash,
        video: data[:video]&.to_hash,

        author: data[:author]&.to_hash,
        provider: data[:provider]&.to_hash,

        fields: data[:fields]&.map(&:to_hash),
      }.delete_if {|_,v| v.nil? }

      embed
    end
  end

  class EmbedFooter
    attr_reader :text

    attr_reader :icon_url

    attr_reader :proxy_icon_url

    def initialize(data)
      @text, @icon_url = data['text'], data['icon_url']
      @proxy_icon_url =  data['proxy_icon_url']
    end

    def to_hash
      {
        text: @text,
        icon_url: @icon_url,
      }.delete_if {|_,v| v.nil? }
    end
  end

  class EmbedMedia
    attr_reader :url

    attr_reader :proxy_url

    attr_reader :width

    attr_reader :height

    def initialize(data)
      @url, @width, @height = data['url'], data['width'], data['height']
      @proxy_url = data['proxy_url']
    end

    def to_hash
      {
        url: @url,
        width: @width,
        height: @height,
      }.delete_if {|_,v| v.nil? }
    end
  end

  class EmbedAuthor
    attr_reader :name

    attr_reader :url

    attr_reader :icon_url

    attr_reader :proxy_icon_url

    def initialize(data)
      @name, @url, @icon_url = data['name'], data['url'], data['icon_url']
      @proxy_icon_url = data['proxy_icon_url']
    end

    def to_hash
      {
        name: @name,
        url: @url,
        icon_url: @icon_url,
      }.delete_if {|_,v| v.nil? }
    end
  end

  class EmbedProvider
    attr_reader :name

    attr_reader :url

    def initialize(data)
      @name, @url = data['name'], data['url']
    end

    def to_hash
      {
        name: @name,
        url: @url,
      }.delete_if {|_,v| v.nil? }
    end
  end

  class EmbedField
    attr_reader :name

    attr_reader :value

    attr_reader :inline

    def initialize(data)
      @name, @value, @inline = data['name'], data['value'], data['inline']
    end

    def to_hash
      {
        name: @name,
        value: @value,
        inline: @inline,
      }.delete_if {|_,v| v.nil? }
    end
  end
end