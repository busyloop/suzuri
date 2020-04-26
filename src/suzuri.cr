require "sodium"
require "zstd"
require "base64"

module Suzuri
  VERSION = "1.0.0"

  # Encodes a Suzuri token.
  #
  # **Examples:**
  # ```
  # # Encode
  # Suzuri.encode("hello world", KEY) # => "wB3AKYBaTwJc..."
  #
  # # Encode with compression disabled
  # Suzuri.encode("hello world", KEY, compress_threshold: UInt64::MAX) # => "xAJyiEKfPLPi..."
  #
  # # Encode with a custom creation timestamp
  # Suzuri.encode("hello world", KEY, Time.utc(1985-10-26)) # => "mArTYmcfLyYy..."
  #
  # # Encode with a higher compression level. Value can be 1-19. Default is 3.
  # Suzuri.encode("hello world", KEY, compress_level: 10) # => "puI8lSpoAox5..."
  # ```
  def self.encode(payload : String | Bytes,
                  key : String | Bytes,
                  timestamp : Time = Time.utc,
                  compress_level = 3,
                  compress_threshold : UInt64 = 512) : String
    cipher = Token::CIPHER.new(Sodium::SecureBuffer.new(key.to_slice))
    nonce = Sodium::Nonce.random

    header = IO::Memory.new(Token::HEADER_SIZE)
    header.write_byte payload.size > compress_threshold ? 0x81_u8 : 0x80_u8
    header.write_bytes timestamp.to_unix.to_u32, IO::ByteFormat::BigEndian
    header.write(nonce.to_slice)

    if payload.size > compress_threshold
      cctx = Zstd::Compress::Context.new(level: compress_level)
      payload = cctx.compress payload.to_slice
    end

    ciphertext, _ = cipher.encrypt(payload, nonce: nonce, additional: header.to_slice)

    raw = Bytes.new(header.size + ciphertext.size)
    header.to_slice.move_to(raw)
    ciphertext.move_to(raw + header.size)

    Base64.urlsafe_encode(raw.to_slice)
  end

  # Decodes a Suzuri token.
  #
  # **Examples:**
  # ```
  # # Decode
  # Suzuri.decode(token, KEY) # => Suzuri::Token
  #
  # # Decode with a ttl constraint
  # Suzuri.decode(token, KEY, 5.minutes) # => Suzuri::Error::TokenExpired
  # ```
  def self.decode(token : String, key : String, ttl : Time::Span? = nil) : Token
    begin
      raw = Base64.decode(token)
    rescue ex : Exception
      raise Error::MalformedInput.new("Base64 decoding failed")
    end

    begin
      timestamp = Time.unix(IO::Memory.new(raw[1..4]).read_bytes(UInt32, IO::ByteFormat::BigEndian))
      header = raw[0..Token::HEADER_SIZE-1]
      ciphertext = raw[Token::HEADER_SIZE..-1]
      nonce = Sodium::Nonce.new(raw[5..4 + Token::NONCE_SIZE])
    rescue ex : Exception
      raise Error::MalformedInput.new(ex.message)
    end

    begin
      cipher = Token::CIPHER.new(Sodium::SecureBuffer.new(key.to_slice))
      payload = cipher.decrypt(ciphertext, nonce: nonce, additional: header.to_slice)
      if raw[0] == 0x81_u8
        dctx = Zstd::Decompress::Context.new
        payload = dctx.decompress payload
      end
    rescue ex : Sodium::Error::DecryptionFailed
      raise Error::DecryptionFailed.new(ex.message)
    end

    raise Error::TokenExpired.new("Token expired at #{timestamp}") if ttl && timestamp + ttl < Time.utc
    Token.new(payload: payload, timestamp: timestamp)
  end

  module Error
    class DecodeError < Exception; end
    class MalformedInput < DecodeError; end
    class TokenExpired < DecodeError; end
    class DecryptionFailed < DecodeError; end
  end

  struct Token
    # :nodoc:
    CIPHER = Sodium::Cipher::Aead::XChaCha20Poly1305Ietf
    # :nodoc:
    NONCE_SIZE = Sodium::Cipher::Aead::XChaCha20Poly1305Ietf::NONCE_SIZE
    # :nodoc:
    HEADER_SIZE = 5 + NONCE_SIZE

    # Returns the creation timestamp
    getter timestamp : Time

    # Returns the decrypted payload as `Bytes`
    getter payload : Bytes

    # Returns the decrypted payload as `String`
    def to_s : String
      String.new(@payload)
    end

    protected def initialize(@timestamp, @payload)
    end
  end
end
