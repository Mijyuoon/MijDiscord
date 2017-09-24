# frozen_string_literal: true

module MijDiscord::Core::Errors
  class InvalidAuthentication < RuntimeError; end

  class MessageTooLong < RuntimeError; end

  class NoPermission < RuntimeError; end

  class CloudflareError < RuntimeError; end

  class CodeError < RuntimeError
    class << self
      attr_reader :code

      def define(code)
        klass = Class.new(CodeError)
        klass.instance_variable_set('@code', code)

        @code_classes ||= {}
        @code_classes[code] = klass

        klass
      end

      def resolve(code)
        @code_classes ||= {}
        @code_classes[code]
      end
    end

    def code
      self.class.code
    end
  end

  UnknownError = CodeError.define(0)

  UnknownAccount = CodeError.define(10_001)

  UnknownApplication = CodeError.define(10_102)

  UnknownChannel = CodeError.define(10_103)

  UnknownServer = CodeError.define(10_004)

  UnknownIntegration = CodeError.define(10_005)

  UnknownInvite = CodeError.define(10_006)

  UnknownMember = CodeError.define(10_007)

  UnknownMessage = CodeError.define(10_008)

  UnknownOverwrite = CodeError.define(10_009)

  UnknownProvider = CodeError.define(10_010)

  UnknownRole = CodeError.define(10_011)

  UnknownToken = CodeError.define(10_012)

  UnknownUser = CodeError.define(10_013)

  EndpointNotForBots = CodeError.define(20_001)

  EndpointOnlyForBots = CodeError.define(20_002)

  ServerLimitReached = CodeError.define(30_001)

  FriendLimitReached = CodeError.define(30_002)

  Unauthorized = CodeError.define(40_001)

  MissingAccess = CodeError.define(50_001)

  InvalidAccountType = CodeError.define(50_002)

  InvalidForDM = CodeError.define(50_003)

  EmbedDisabled = CodeError.define(50_004)

  MessageAuthoredByOtherUser = CodeError.define(50_005)

  MessageEmpty = CodeError.define(50_006)

  NoMessagesToUser = CodeError.define(50_007)

  NoMessagesInVoiceChannel = CodeError.define(50_008)

  VerificationLevelTooHigh = CodeError.define(50_009)

  NoBotForApplication = CodeError.define(50_010)

  ApplicationLimitReached = CodeError.define(50_011)

  InvalidOAuthState = CodeError.define(50_012)

  MissingPermissions = CodeError.define(50_013)

  InvalidAuthToken = CodeError.define(50_014)

  NoteTooLong = CodeError.define(50_015)

  InvalidBulkDeleteCount = CodeError.define(50_016)
end