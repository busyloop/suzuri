require "./spec_helper"

TEST_KEY = "TheKeyLengthMustBeThirtyTwoBytes"

class JsonDemo
  include JSON::Serializable

  @[JSON::Field]
  property text : String

  @[JSON::Field]
  property float : Float64

  @[JSON::Field]
  property time : Time

  def initialize(@text, @float, @time)
  end
end

describe Suzuri do
  it "decodes what it previously encoded" do
    token = Suzuri.encode("hello world", TEST_KEY)
    decoded = Suzuri.decode(token, TEST_KEY)
    String.new(decoded.payload).should eq "hello world"
  end

  it "compresses the payload above a size-threshold" do
    payload = "x" * 16384

    token_nc = Suzuri.encode(payload, TEST_KEY, compress_threshold: UInt64::MAX)
    token_c = Suzuri.encode(payload, TEST_KEY, compress_threshold: 0)

    token_c.size.should be < token_nc.size

    # ensure both tokens decode
    Suzuri.decode(token_nc, TEST_KEY).to_s.should eq payload
    Suzuri.decode(token_c, TEST_KEY).to_s.should eq payload
  end

  it "raises on encode when key is not 32 bytes long" do
    expect_raises(ArgumentError, /key size mismatch/) do
      Suzuri.encode("hello world", "too short")
    end

    expect_raises(ArgumentError, /key size mismatch/) do
      Suzuri.encode("hello world", TEST_KEY + "too long")
    end
  end

  it "raises on decode when key is not 32 bytes long" do
    token = Suzuri.encode("hello world", TEST_KEY)
    expect_raises(ArgumentError, /key size mismatch/) do
      Suzuri.decode(token, "too short")
    end

    expect_raises(ArgumentError, /key size mismatch/) do
      Suzuri.decode(token, TEST_KEY + "too long")
    end
  end

  it "includes a timestamp with encoded tokens" do
    Timecop.freeze(Time.utc(1990,1,1)) do |frozen_time|
      token = Suzuri.encode("hello world", TEST_KEY)
      decoded = Suzuri.decode(token, TEST_KEY)
      decoded.timestamp.should eq frozen_time
    end
  end

  it "allows encoded timestamp to be overridden" do
    Timecop.freeze(Time.utc(1990,1,1)) do
      token = Suzuri.encode("hello world", TEST_KEY, Time.utc(2000,1,1))
      decoded = Suzuri.decode(token, TEST_KEY)
      decoded.timestamp.should eq Time.utc(2000,1,1)
    end
  end

  it "raises on decode when decryption fails (e.g. wrong key)" do
    token = Suzuri.encode("hello world", TEST_KEY, Time.utc(2000,1,1))
    expect_raises(Suzuri::Error::DecryptionFailed) do
      Suzuri.decode(token, "WrongSecretxxxxxxxxxxxxxxxxxxxxx")
    end
  end

  it "raises on decode when ttl is expired" do
    token = Suzuri.encode("hello world", TEST_KEY, Time.utc(2000,1,1))
    expect_raises(Suzuri::Error::TokenExpired) do
      Suzuri.decode(token, TEST_KEY, 5.seconds)
    end
  end

  it "raises on decode when input is not base64" do
    not_a_token = "I'm not a token"
    expect_raises(Suzuri::Error::MalformedInput) do
      Suzuri.decode(not_a_token, TEST_KEY)
    end
  end

  it "raises on decode when base64 content isn't a suzuri token" do
    not_a_token = Base64.urlsafe_encode("I'm not a token")
    expect_raises(Suzuri::Error::MalformedInput) do
      Suzuri.decode(not_a_token, TEST_KEY)
    end
  end
end

describe JSON::Serializable do
  it "encodes/decodes JSON::Serializable objects via to_suzuri/from_suzuri" do
    demo = JsonDemo.new(text: "hello world", float: 0.42, time: Time.utc(1,1,1))

    token = demo.to_suzuri(TEST_KEY)

    decoded = JsonDemo.from_suzuri(token, TEST_KEY)
    decoded.text.should eq demo.text
    decoded.float.should eq demo.float
    decoded.time.should eq demo.time
  end

  it "decodes JSON::Serializable objects with timestamp via from_suzuri_with_timestamp" do
    demo = JsonDemo.new(text: "hello world", float: 0.42, time: Time.utc(1,1,1))

    token = demo.to_suzuri(TEST_KEY)

    decoded, timestamp = JsonDemo.from_suzuri_with_timestamp(token, TEST_KEY)
    decoded.text.should eq demo.text
    decoded.float.should eq demo.float
    decoded.time.should eq demo.time
    timestamp.should be_a Time
  end
end
