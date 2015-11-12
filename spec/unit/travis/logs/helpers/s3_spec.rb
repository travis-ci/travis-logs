require 'travis/logs/helpers/s3'

class FakeS3Object
  def write(_data, _options)
    :written
  end

  def content_length
    42
  end
end

class FakeS3Bucket
  attr_reader :objects

  def initialize
    @objects = { 'some/data' => FakeS3Object.new }
  end
end

class FakeS3
  attr_reader :buckets

  def initialize
    @buckets = { 'foo.example.com' => FakeS3Bucket.new }
  end
end

describe Travis::Logs::Helpers::S3 do
  subject do
    inst = described_class.new
    inst.instance_variable_set(:@s3, fake_s3)
    inst
  end

  let(:fake_s3) { FakeS3.new }

  before do
    allow(AWS).to receive(:config)
    allow(AWS::S3).to receive(:new).and_return(:bluh)
  end

  it 'configures aws' do
    expect(described_class.setup).to eql(:alldone)
  end

  it 'exposes a #store convenience method' do
    expect(
      subject.store('some data for you', 'http://foo.example.com/some/data')
    ).to eql(:written)
  end

  it 'exposes a #content_length convenience method' do
    expect(
      subject.content_length('http://foo.example.com/some/data')
    ).to eql(42)
  end
end
