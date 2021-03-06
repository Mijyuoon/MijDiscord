# frozen_string_literal: true

module MijDiscord
  LOGGER = Logger.new(STDOUT, level: :error)

  LOGGER.formatter = proc do |sev, ts, prg, msg|
    time = ts.strftime '%Y-%m-%d %H:%M:%S %z'
    text = case msg
      when Exception
        trace = msg.backtrace.map {|x| "TRACE> #{x}" }
        "#{msg.message} (#{msg.class})\n#{trace.join("\n")}"
      when String
        msg
      else
        msg.inspect
    end

    "[#{sev}] [#{time}] #{prg.upcase}: #{text}\n"
  end

  def self.make_inspect(obj, *vars)
    data = [obj.class.to_s.split('::').last]
    data += vars.map do |x|
      value = obj.instance_variable_get(:"@#{x}")
      "#{x}=#{value.inspect}"
    end
    %(#<#{data.join(' ')}>)
  end
end