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

    describe 'GET /uptime' do
      it 'returns 204' do
        response = get '/uptime'
        expect(response.status).to eql 204
      end
    end

    describe 'POST /pusher/existence' do
      it 'sets proper properties on channel' do
        expect(existence.occupied?('foo')).to be_falsey
        expect(existence.occupied?('bar')).to be_falsey

        webhook = OpenStruct.new(valid?: true, events: [
          { 'name' => 'channel_occupied', 'channel' => 'foo' },
          { 'name' => 'channel_vacated',  'channel' => 'bar' }
        ])
        expect(pusher).to receive(:webhook) { |request|
          request.path_info == '/pusher/existence'
          webhook
        }

        response = post '/pusher/existence'
        expect(response.status).to eql 204

        expect(existence.occupied?('foo')).to be_truthy
        expect(existence.occupied?('bar')).to be_falsey

        webhook = OpenStruct.new(valid?: true, events: [
          { 'name' => 'channel_vacated', 'channel' => 'foo' },
          { 'name' => 'channel_occupied',  'channel' => 'bar' }
        ])
        expect(pusher).to receive(:webhook) { |request|
          request.path_info == '/pusher/existence'
          webhook
        }

        response = post '/pusher/existence'
        expect(response.status).to eql 204

        expect(existence.occupied?('foo')).to be_falsey
        expect(existence.occupied?('bar')).to be_truthy
      end

      it 'responds with 401 with invalid webhook' do
        webhook = OpenStruct.new(valid?: false)
        expect(pusher).to receive(:webhook) { |request|
          request.path_info == '/pusher/existence'
          webhook
        }

        response = post '/pusher/existence'
        expect(response.status).to eql 401
      end
    end
  end
end
