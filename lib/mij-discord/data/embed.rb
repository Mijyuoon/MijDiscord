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
  end

  class EmbedFooter
    attr_reader :text

    attr_reader :icon_url

    attr_reader :proxy_icon_url

    def initialize(data)
      @text, @icon_url = data['text'], data['icon_url']
      @proxy_icon_url =  data['proxy_icon_url']
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
  end

  class EmbedProvider
    attr_reader :name

    attr_reader :url

    def initialize(data)
      @name, @url = data['name'], data['url']
    end
  end

  class EmbedField
    attr_reader :name

    attr_reader :value

    attr_reader :inline

    def initialize(data)
      @name, @value, @inline = data['name'], data['value'], data['inline']
    end
  end
end