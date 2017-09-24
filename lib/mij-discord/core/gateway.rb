# frozen_string_literal: true

module MijDiscord::Core
  # Gateway packet opcodes
  module Opcodes
    # **Received** when Discord dispatches an event to the gateway (like MESSAGE_CREATE, PRESENCE_UPDATE or whatever).
    # The vast majority of received packets will have this opcode.
    DISPATCH = 0

    # **Two-way**: The client has to send a packet with this opcode every ~40 seconds (actual interval specified in
    # READY or RESUMED) and the current sequence number, otherwise it will be disconnected from the gateway. In certain
    # cases Discord may also send one, specifically if two clients are connected at once.
    HEARTBEAT = 1

    # **Sent**: This is one of the two possible ways to initiate a session after connecting to the gateway. It
    # should contain the authentication token along with other stuff the server has to know right from the start, such
    # as large_threshold and, for older gateway versions, the desired version.
    IDENTIFY = 2

    # **Sent**: Packets with this opcode are used to change the user's status and played game. (Sending this is never
    # necessary for a gateway client to behave correctly)
    PRESENCE = 3

    # **Sent**: Packets with this opcode are used to change a user's voice state (mute/deaf/unmute/undeaf/etc.). It is
    # also used to connect to a voice server in the first place. (Sending this is never necessary for a gateway client
    # to behave correctly)
    VOICE_STATE = 4

    # **Sent**: This opcode is used to ping a voice server, whatever that means. The functionality of this opcode isn't
    # known well but non-user clients should never send it.
    VOICE_PING = 5

    # **Sent**: This is the other of two possible ways to initiate a gateway session (other than {IDENTIFY}). Rather
    # than starting an entirely new session, it resumes an existing session by replaying all events from a given
    # sequence number. It should be used to recover from a connection error or anything like that when the session is
    # still valid - sending this with an invalid session will cause an error to occur.
    RESUME = 6

    # **Received**: Discord sends this opcode to indicate that the client should reconnect to a different gateway
    # server because the old one is currently being decommissioned. Counterintuitively, this opcode also invalidates the
    # session - the client has to create an entirely new session with the new gateway instead of resuming the old one.
    RECONNECT = 7

    # **Sent**: This opcode identifies packets used to retrieve a list of members from a particular server. There is
    # also a REST endpoint available for this, but it is inconvenient to use because the client has to implement
    # pagination itself, whereas sending this opcode lets Discord handle the pagination and the client can just add
    # members when it receives them. (Sending this is never necessary for a gateway client to behave correctly)
    REQUEST_MEMBERS = 8

    # **Received**: Sent by Discord when the session becomes invalid for any reason. This may include improperly
    # resuming existing sessions, attempting to start sessions with invalid data, or something else entirely. The client
    # should handle this by simply starting a new session.
    INVALIDATE_SESSION = 9

    # **Received**: Sent immediately for any opened connection; tells the client to start heartbeating early on, so the
    # server can safely search for a session server to handle the connection without the connection being terminated.
    # As a side-effect, large bots are less likely to disconnect because of very large READY parse times.
    HELLO = 10

    # **Received**: Returned after a heartbeat was sent to the server. This allows clients to identify and deal with
    # zombie connections that don't dispatch any events anymore.
    HEARTBEAT_ACK = 11
  end

  # @!visibility private
  class Session
    attr_reader :session_id
    attr_accessor :sequence

    def initialize(session_id)
      @session_id = session_id
      @sequence = 0
      @suspended = false
      @invalid = false
    end

    def suspend
      @suspended = true
    end

    def resume
      @suspended = false
    end

    def suspended?
      @suspended
    end

    def invalidate
      @invalid = true
    end

    def invalid?
      @invalid
    end

    def should_resume?
      @suspended && !@invalid
    end
  end

  class Gateway
    GATEWAY_VERSION = 6

    LARGE_THRESHOLD = 100

    attr_accessor :check_heartbeat_acks

    def initialize(bot, token, shard_key = nil)
      @bot, @token, @shard_key = bot, token, shard_key

      @ws_success = false
      @getc_mutex = Mutex.new

      @check_heartbeat_acks = true
    end

    def run_async
      @ws_thread = Thread.new do
        Thread.current[:mij_discord] = 'websocket'

        @reconnect_delay = 1.0

        loop do
          ws_connect

          break unless @should_reconnect

          if @instant_reconnect
            @reconnect_delay = 1.0
            @instant_reconnect = false
          else
            sleep(@reconnect_delay)
            @reconnect_delay = [@reconnect_delay * 1.5, 120].min
          end
        end

        MijDiscord::LOGGER.info('Gateway') { 'Websocket loop has been terminated' }
      end

      sleep(0.2) until @ws_success
      MijDiscord::LOGGER.info('Gateway') { 'Connection established and confirmed' }
      nil
    end

    def sync
      @ws_thread&.join
      nil
    end

    def kill
      @ws_thread&.kill
      nil
    end

    def open?
      @handshake&.finished? && !@ws_closed
    end

    def stop(no_sync = false)
      @should_reconnect = false
      ws_close(no_sync)
      nil
    end

    def heartbeat
      if check_heartbeat_acks
        unless @last_heartbeat_acked
          MijDiscord::LOGGER.warn('Gateway') { 'Heartbeat not acknowledged, attempting to reconnect' }

          @broken_pipe = true
          reconnect(true)
          return
        end

        @last_heartbeat_acked = false
      end

      send_heartbeat(@session&.sequence || 0)
    end

    def reconnect(try_resume = true)
      @session&.suspend if try_resume

      @instant_reconnect = true
      @should_reconnect = true

      ws_close(false)
      nil
    end

    def send_heartbeat(sequence)
      send_packet(Opcodes::HEARTBEAT, sequence)
    end

    def send_identify(token, properties, compress, large_threshold, shard_key)
      data = {
        token: token,
        properties: properties,
        compress: compress,
        large_threshold: large_threshold,
      }

      data[:shard] = shard_key if shard_key

      send_packet(Opcodes::IDENTIFY, data)
    end

    def send_status_update(status, since, game, afk)
      data = {
        status: status,
        since: since,
        game: game,
        afk: afk,
      }

      send_packet(Opcodes::PRESENCE, data)
    end

    def send_voice_state_update(server_id, channel_id, self_mute, self_deaf)
      data = {
        guild_id: server_id,
        channel_id: channel_id,
        self_mute: self_mute,
        self_deaf: self_deaf,
      }

      send_packet(Opcodes::VOICE_STATE, data)
    end

    def send_resume(token, session_id, sequence)
      data = {
        token: token,
        session_id: session_id,
        seq: sequence,
      }

      send_packet(Opcodes::RESUME, data)
    end

    def send_request_members(server_id, query, limit)
      data = {
        guild_id: server_id,
        query: query,
        limit: limit,
      }

      send_packet(Opcodes::REQUEST_MEMBERS, data)
    end

    def send_packet(opcode, packet)
      data = {
        op: opcode,
        d: packet,
      }

      ws_send(data.to_json, :text)
      nil
    end

    def send_raw(data, type = :text)
      ws_send(data, type)
      nil
    end

    def notify_ready
      @ws_success = true
    end

    private

    def send_identify_self
      props = {
          '$os': RUBY_PLATFORM,
          '$browser': 'mij-discord',
          '$device': 'mij-discord',
          '$referrer': '',
          '$referring_domain': '',
      }

      send_identify(@token, props, true, LARGE_THRESHOLD, @shard_key)
    end

    def send_resume_self
      send_resume(@token, @session.session_id, @session.sequence)
    end

    def setup_heartbeat(interval)
      @last_heartbeat_acked = true

      return if @heartbeat_thread

      @heartbeat_thread = Thread.new do
        Thread.current[:mij_discord] = 'heartbeat'

        loop do
          begin
            if @session&.suspended?
              sleep(1.0)
            else
              sleep(interval)
              @bot.handle_heartbeat
              heartbeat
            end
          rescue => exc
            MijDiscord::LOGGER.error('Gateway') { 'An error occurred during heartbeat' }
            MijDiscord::LOGGER.error('Gateway') { exc }
          end
        end
      end
    end

    def obtain_socket(uri)
      secure = %w[https wss].include?(uri.scheme)
      socket = TCPSocket.new(uri.host, uri.port || (secure ? 443 : 80))

      if secure
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.ssl_version = 'SSLv23'
        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE # use VERIFY_PEER for verification

        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths
        ctx.cert_store = cert_store

        socket = OpenSSL::SSL::SSLSocket.new(socket, ctx)
        socket.connect
      end

      socket
    end

    def get_gateway_url
      response = API.gateway(@token)
      raw_url = JSON.parse(response)['url']
      raw_url << '/' unless raw_url.end_with? '/'
      "#{raw_url}?encoding=json&v=#{GATEWAY_VERSION}"
    end

    def ws_connect
      url = get_gateway_url
      gateway_uri = URI.parse(url)

      @socket = obtain_socket(gateway_uri)
      @handshake = WebSocket::Handshake::Client.new(url: url)
      @handshake_done, @broken_pipe, @ws_closed = false, false, false

      ws_mainloop
    rescue => exc
      MijDiscord::LOGGER.error('Gateway') { 'An error occurred during websocket connect' }
      MijDiscord::LOGGER.error('Gateway') { exc }
    end

    def ws_mainloop
      @bot.handle_dispatch(:CONNECT, nil)

      @socket.write(@handshake.to_s)

      frame = WebSocket::Frame::Incoming::Client.new

      until @ws_closed
        begin
          unless @socket
            ws_close(false)
            MijDiscord::LOGGER.error('Gateway') { 'Socket object is nil in main websocket loop' }
          end

          recv_data = nil
          @getc_mutex.synchronize { recv_data = @socket&.getc }

          unless recv_data
            sleep(1.0)
            next
          end

          if @handshake_done
            frame << recv_data

            loop do
              msg = frame.next
              break unless msg

              if msg.respond_to?(:code) && msg.code
                MijDiscord::LOGGER.warn('Gateway') { 'Received websocket close frame' }
                MijDiscord::LOGGER.warn('Gateway') { "(code: #{msg.code}, info: #{msg.data})" }

                codes = [1000, 4004, 4010, 4011]
                if codes.include?(msg.code)
                  ws_close(false)
                else
                  MijDiscord::LOGGER.warn('Gateway') { 'Non-fatal code, attempting to reconnect' }
                  reconnect(true)
                end

                break
              end

              handle_message(msg.data)
            end
          else
            @handshake << recv_data
            @handshake_done = true if @handshake.finished?
          end
        rescue Errno::ECONNRESET
          @broken_pipe = true
          reconnect(true)
          MijDiscord::LOGGER.warn('Gateway') { 'Connection reset by remote host, attempting to reconnect' }
        rescue => exc
          MijDiscord::LOGGER.error('Gateway') { 'An error occurred in main websocket loop' }
          MijDiscord::LOGGER.error('Gateway') { exc }
        end
      end
    end

    def ws_send(data, type)
      unless @handshake_done && !@ws_closed
        raise StandardError, 'Tried to send something to the websocket while not being connected!'
      end

      frame = WebSocket::Frame::Outgoing::Client.new(data: data, type: type, version: @handshake.version)

      begin
        @socket.write frame.to_s
      rescue => e
        @broken_pipe = true
        ws_close(false)
        MijDiscord::LOGGER.error('Gateway') { 'An error occurred during websocket write' }
        MijDiscord::LOGGER.error('Gateway') { e }
      end
    end

    def ws_close(no_sync)
      return if @ws_closed

      @session&.suspend

      ws_send(nil, :close) unless @broken_pipe

      if no_sync
        @ws_closed = true
      else
        @getc_mutex.synchronize { @ws_closed = true }
      end

      @socket&.close
      @socket = nil

      @bot.handle_dispatch(:DISCONNECT, nil)
    end

    def handle_message(msg)
      msg = Zlib::Inflate.inflate(msg) if msg.byteslice(0) == 'x'

      packet = JSON.parse(msg)
      @session&.sequence = packet['s'] if packet['s']

      case (opc = packet['op'].to_i)
        when Opcodes::DISPATCH
          handle_dispatch(packet)
        when Opcodes::HELLO
          handle_hello(packet)
        when Opcodes::RECONNECT
          reconnect
        when Opcodes::INVALIDATE_SESSION
          @session&.invalidate
          send_identify_self
        when Opcodes::HEARTBEAT_ACK
          @last_heartbeat_acked = true if @check_heartbeat_acks
        when Opcodes::HEARTBEAT
          send_heartbeat(packet['s'])
        else
          MijDiscord::LOGGER.error('Gateway') { "Invalid opcode received: #{opc}" }
      end
    end

    def handle_dispatch(packet)
      data, type = packet['d'], packet['t'].to_sym

      case type
        when :READY
          @session = Session.new(data['session_id'])

          MijDiscord::LOGGER.info('Gateway') { "Received READY packet (user: #{data['user']['id']})" }
          MijDiscord::LOGGER.info('Gateway') { "Using gateway protocol version #{data['v']}, requested #{GATEWAY_VERSION}" }
        when :RESUMED
          MijDiscord::LOGGER.info('Gateway') { 'Received session resume confirmation' }
          return
      end

      @bot.handle_dispatch(type, data)
    end

    def handle_hello(packet)
      interval = packet['d']['heartbeat_interval'].to_f / 1000.0
      setup_heartbeat(interval)

      if @session&.should_resume?
        @session.resume
        send_resume_self
      else
        send_identify_self
      end
    end
  end
end