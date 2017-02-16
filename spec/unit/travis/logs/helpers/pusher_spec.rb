require 'travis/logs'
require 'travis/logs/helpers/pusher'

describe Travis::Logs::Helpers::Pusher do
  let(:pusher_client) { double('pusher-client') }
  let(:pusher_channel) { double('pusher-channel') }
  let(:pusher_helper) { described_class.new(pusher_client) }

  let(:payload) do
    {
      'id' => '1919',
      'chars' => 'strike! ✊',
      'number' => '204',
      'final' => false
    }
  end

  before(:each) do
    allow(pusher_client).to receive(:[]) { pusher_channel }
    allow(pusher_channel).to receive(:trigger)
    allow(pusher_helper).to receive(:secure?).and_return(false)
  end

  it 'pushing a payload triggers a job:log message' do
    pusher_helper.push(payload)

    expect(pusher_client).to have_received(:[]).with('job-1919')
    expect(pusher_channel).to have_received(:trigger)
      .with(
        'job:log',
        '{"id":"1919","_log":"strike! ✊","number":"204","final":false}'
      )
  end
end
