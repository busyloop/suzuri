# Suzuri
![Build](https://github.com/busyloop/suzuri/workflows/Build/badge.svg) [![GitHub](https://img.shields.io/github/license/busyloop/suzuri)](https://en.wikipedia.org/wiki/MIT_License) [![GitHub release](https://img.shields.io/github/release/busyloop/suzuri.svg)](https://github.com/busyloop/suzuri/releases)

Suzuri is a secure and easy to use token format that employs  
[IETF XChaCha20-Poly1305 AEAD](https://libsodium.gitbook.io/doc/secret-key_cryptography/aead/chacha20-poly1305/ietf_chacha20-poly1305_construction) symmetric encryption to  
create authenticated, encrypted, tamperproof tokens.  

It compresses and encrypts an arbitrary sequence of bytes,  
then encodes the result to url-safe Base64.

Suzuri tokens can be used as a secure alternative to JWT  
or for any type of general purpose message passing.


## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     suzuri:
       github: busyloop/suzuri
   ```

2. Run `shards install`

## Documentation

* [API Documentation](https://busyloop.github.io/suzuri/Suzuri.html)


## Usage

```crystal
require "suzuri"

TEST_KEY = "TheKeyLengthMustBeThirtyTwoBytes"

## Encode
token_str = Suzuri.encode("hello world", TEST_KEY) # => "(url-safe base64)"

## Decode
token = Suzuri.decode(token_str, TEST_KEY)   # => Suzuri::Token
token.to_s                                   # => "hello world"
token.timestamp                              # => 2020-01-01 01:23:45.0 UTC

## Decode with a TTL constraint
token_str = Suzuri.encode("hello world", TEST_KEY) # => "(url-safe base64)"
sleep 5
Suzuri.decode(token_str, TEST_KEY, 2.seconds) # => Suzuri::Error::TokenExpired
```

## Usage (with [JSON::Serializable](https://crystal-lang.org/api/0.34.0/JSON/Serializable.html))

```crystal
require "suzuri/json_serializable"

TEST_KEY = "TheKeyLengthMustBeThirtyTwoBytes"

class Person
   include JSON::Serializable

   @[JSON::Field]
   property name : String

   def initialize(@name)
   end
end

bob = Person.new(name: "bob")
token_str = bob.to_suzuri(TEST_KEY)

bob2 = Person.from_suzuri(token_str, TEST_KEY)
bob2.name # => "bob"
```


## Compression

By default Suzuri applies zstd compression before encryption when the  
payload is larger than 512 bytes. The compression threshold and level  
can be chosen at runtime.


## Contributing

1. Fork it (<https://github.com/busyloop/suzuri/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Credits

Suzuri is inspired by (but not compatible to) [Branca](https://github.com/tuupola/branca-spec/)-tokens. The underlying encryption is identical.  
Suzuri adds compression support and serializes to url-safe Base64 instead of Base62.

