# frozen_string_literal: true

require 'set'
require 'logger'
require 'base64'
require 'thread'
require 'json'
require 'time'
require 'socket'
require 'openssl'
require 'zlib'
require 'websocket-client-simple'
require 'rest-client'

require_relative 'mij-discord/version'
require_relative 'mij-discord/logger'
require_relative 'mij-discord/cache'
require_relative 'mij-discord/events'

require_relative 'mij-discord/core/gateway'
require_relative 'mij-discord/core/errors'
require_relative 'mij-discord/core/api'
require_relative 'mij-discord/core/api/channel'
require_relative 'mij-discord/core/api/invite'
require_relative 'mij-discord/core/api/server'
require_relative 'mij-discord/core/api/user'

require_relative 'mij-discord/data'
require_relative 'mij-discord/data/invite'
require_relative 'mij-discord/data/voice'
require_relative 'mij-discord/data/permissions'
require_relative 'mij-discord/data/application'
require_relative 'mij-discord/data/user'
require_relative 'mij-discord/data/member'
require_relative 'mij-discord/data/role'
require_relative 'mij-discord/data/channel'
require_relative 'mij-discord/data/server'
require_relative 'mij-discord/data/embed'
require_relative 'mij-discord/data/emoji'
require_relative 'mij-discord/data/message'

require_relative 'mij-discord/events/basic'
require_relative 'mij-discord/events/server'
require_relative 'mij-discord/events/member'
require_relative 'mij-discord/events/channel'
require_relative 'mij-discord/events/message'

require_relative 'mij-discord/bot'

class Integer
  alias_method :to_id, :itself
end

class String
  alias_method :to_id, :to_i
end