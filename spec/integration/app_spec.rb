require 'ostruct'
require 'travis/logs'
require 'travis/logs/app'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

module Travis::Logs
  describe App do
    include Rack::Test::Methods

    def app
      Travis::Logs::App.new(nil, pusher, database)
    end

    let(:pusher) { double(:pusher) }
    let(:existence) { Travis::Logs::Existence.new }
    let(:database) { double(:database) }

    before do
      existence.vacant!('foo')
      existence.vacant!('bar')
    end

    describe 'GET /uptime' do
      it 'returns 204' do
        response = get '/uptime'
        response.status.should == 204
      end
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

    describe "POST /logs/:id/clear" do
      before do
        @log_id = 123
        @old_auth_token = ENV["AUTH_TOKEN"]
        @auth_token = ENV["AUTH_TOKEN"] = "very-secret"

        allow(database).to receive(:clear_log)
        allow(database).to receive(:log_for_id).with(anything()).and_return(nil)
        allow(database).to receive(:log_for_id).with(@log_id).and_return({ content: "" })
      end

      after do
        ENV["AUTH_TOKEN"] = @old_auth_token
      end

      it "returns 500 if the auth token isn't set" do
        ENV["AUTH_TOKEN"] = ""
        header "Authorization", "token "
        expect { post "/logs/#{@log_id}/clear" }.to raise_error(/token/)
      end

      it "returns 403 if the Authorization header isn't set" do
        response = post "/logs/#{@log_id}/clear"
        expect(response.status).to be == 403
      end

      it "returns 403 if the Authorization header is incorrect" do
        header "Authorization", "token not-#{@auth_token}"
        response = post "/logs/#{@log_id}/clear"
        expect(response.status).to be == 403
      end

      it "returns 204 if the Authorization header is correct" do
        header "Authorization", "token #{@auth_token}"
        response = post "/logs/#{@log_id}/clear"
        expect(response.status).to be == 204
      end

      it "returns 404 if the log doesn't exist" do
        header "Authorization", "token #{@auth_token}"
        response = post "/logs/#{@log_id+1}/clear"
        expect(response.status).to be == 404
      end

      it "tells the database to clear the log" do
        header "Authorization", "token #{@auth_token}"
        expect(database).to receive(:clear_log).with(@log_id)
        post "/logs/#{@log_id}/clear"
      end
    end
  end
end
