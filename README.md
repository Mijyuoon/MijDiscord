# MijDiscord

My Discord bot library that's partially based on Discordrb. Was made because I found Discordrb to be not satisfactory for my purposes.

TODO: Write goddamn documentation because there's currently none.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mij-discord'
```

And then execute:

```
$ bundle
```

Or install it yourself as:

```
$ gem install mij-discord
```

## Usage

```ruby
require "mij-discord"

bot = MijDiscord::Bot.new(client_id:<here client id>, token:<here token>)

bot.add_event(:create_message) do |event|
  event.channel.send_message(text: "Pong!") if event.content == "Ping!"
end

bot.connect(false)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Mijyuoon/MijDiscord.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
