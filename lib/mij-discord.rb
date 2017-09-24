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

require 'mij-discord/version'
require 'mij-discord/logger'
require 'mij-discord/cache'
require 'mij-discord/events'

require 'mij-discord/core/gateway'
require 'mij-discord/core/errors'
require 'mij-discord/core/api'
require 'mij-discord/core/api/channel'
require 'mij-discord/core/api/invite'
require 'mij-discord/core/api/server'
require 'mij-discord/core/api/user'

require 'mij-discord/data'
require 'mij-discord/data/invite'
require 'mij-discord/data/voice'
require 'mij-discord/data/permissions'
require 'mij-discord/data/application'
require 'mij-discord/data/user'
require 'mij-discord/data/member'
require 'mij-discord/data/role'
require 'mij-discord/data/channel'
require 'mij-discord/data/server'
require 'mij-discord/data/embed'
require 'mij-discord/data/emoji'
require 'mij-discord/data/message'

require 'mij-discord/events/basic'
require 'mij-discord/events/server'
require 'mij-discord/events/member'
require 'mij-discord/events/channel'
require 'mij-discord/events/message'

require 'mij-discord/bot'

class Integer
  alias_method :to_id, :itself
end

class String
  alias_method :to_id, :to_i
end