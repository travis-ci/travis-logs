require 'travis/logs/helpers/pusher'

class FakePusherChannel
  def trigger(_event, _payload)
    :triggered
  end
end

describe Travis::Logs::Helpers::Pusher do
  subject { described_class.new(fake_pusher_client) }
  let(:fake_pusher_client) { { 'job-1' => FakePusherChannel.new } }

  before do
    Travis::Logs.config.pusher.secure = false
  end

  it 'exposes a #push convenience method' do
    expect(subject.push('id' => '1')).to eql(:triggered)
  end

  it 'exposes a #pusher_channel_name convenience method' do
    expect(subject.pusher_channel_name('id' => '42')).to eql('job-42')
  end
end
