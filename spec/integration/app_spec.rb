require 'ostruct'
require 'travis/logs'
require 'travis/logs/app'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

module Travis::Logs
  describe App do
    include Rack::Test::Methods

    def app
      Travis::Logs::App.new(nil, pusher)
    end

    let(:pusher) { double(:pusher) }
    let(:existence) { Travis::Logs::Existence.new }

    before do
      existence.vacant!('foo')
      existence.vacant!('bar')
    end

    describe 'POST /pusher/existence' do
      it 'sets proper properties on channel' do
        existence.occupied?('foo').should be_false
        existence.occupied?('bar').should be_false

        webhook = OpenStruct.new(valid?: true, events: [
          { 'name' => 'channel_occupied', 'channel' => 'foo' },
          { 'name' => 'channel_vacated',  'channel' => 'bar' }
        ])
        pusher.should_receive(:webhook) { |request|
          request.path_info == '/pusher/existence'
          webhook
        }

        response = post '/pusher/existence'
        response.status.should == 204

        existence.occupied?('foo').should be_true
        existence.occupied?('bar').should be_false

        webhook = OpenStruct.new(valid?: true, events: [
          { 'name' => 'channel_vacated', 'channel' => 'foo' },
          { 'name' => 'channel_occupied',  'channel' => 'bar' }
        ])
        pusher.should_receive(:webhook) { |request|
          request.path_info == '/pusher/existence'
          webhook
        }

        response = post '/pusher/existence'
        response.status.should == 204

        existence.occupied?('foo').should be_false
        existence.occupied?('bar').should be_true
      end

      it 'responds with 401 with invalid webhook' do
        webhook = OpenStruct.new(valid?: false)
        pusher.should_receive(:webhook) { |request|
          request.path_info == '/pusher/existence'
          webhook
        }

        response = post '/pusher/existence'
        response.status.should == 401
      end
    end
  end
end
