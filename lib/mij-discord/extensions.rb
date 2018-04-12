# frozen_string_literal: true

class Integer
  alias_method :to_id, :itself
end

class String
  alias_method :to_id, :to_i
end

class Hash
  def try_keys(*keys)
    keys.each {|k| return self[k] if key?(k) }
    nil
  end
end