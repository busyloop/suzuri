require "../suzuri"

# Use `require "suzuri/json_serializable"` to add
# `#to_suzuri`, `#from_suzuri` and `#from_suzuri_with_timestamp`
# methods to all `JSON::Serializable` objects.
#
# **Example usage:**
#
# ```
# require "suzuri/json_serializable"
#
# class Person
#   include JSON::Serializable
#
#   @[JSON::Field(key: "name")]
#   property name : String
#
#   def initialize(@name)
#   end
# end
#
# bob = Person.new(name: "bob")
# token = bob.to_suzuri(KEY)
#
# decoded = Person.from_suzuri(token, KEY)
# decoded.name # => "bob"
#
# # Decode with timestamp
# decoded, timestamp = Person.from_suzuri_with_timestamp(token, KEY)
# decoded.name # => "bob"
# timestamp    # => Time
# ```
module JSON::Serializable
  # :nodoc:
  def to_suzuri(key : String,
                timestamp : Time = Time.utc,
                compress_level = 3,
                compress_threshold : UInt64 = 512)
    token = Suzuri.encode(to_json, key, timestamp, compress_level, compress_threshold)
  end

  macro included
    # :nodoc:
    def self.from_suzuri(token : String, key : String, ttl : Time::Span? = nil)
      token = Suzuri.decode(token, key, ttl)
      from_json(token.to_s)
    end

    # :nodoc:
    def self.from_suzuri_with_timestamp(token : String, key : String, ttl : Time::Span? = nil)
      token = Suzuri.decode(token, key, ttl)
      { from_json(token.to_s), token.timestamp }
    end
  end
end
