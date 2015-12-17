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

    describe "PUT /logs/:id" do
      before do
        @job_id = 123
        @log_id = 234
        @old_auth_token = ENV["AUTH_TOKEN"]
        @auth_token = ENV["AUTH_TOKEN"] = "very-secret"

        allow(database).to receive(:set_log_content)
        allow(database).to receive(:log_for_job_id).with(anything()).and_return(nil)
        allow(database).to receive(:log_for_job_id).with(@job_id).and_return({ id: @log_id, job_id: @job_id, content: "" })
      end

      after do
        ENV["AUTH_TOKEN"] = @old_auth_token
      end

      context "with correct authentication" do
        before do
          header "Authorization", "token #{@auth_token}"
        end

        it "returns 204" do
          response = put "/logs/#{@job_id}"
          expect(response.status).to be == 204
        end

        it "creates the log if it doesn't exist" do
          expect(database).to receive(:create_log).with(@job_id+1).and_return({ id: @log_id+1, job_id: @job_id+1, content: "" })

          response = put "/logs/#{@job_id+1}"
          expect(response.status).to be == 204
        end

        it "tells the database to set the log content" do
          expect(database).to receive(:set_log_content).with(@log_id, "hello, world")
          put "/logs/#{@job_id}", "hello, world"
        end
      end

      xit "returns 500 if the auth token isn't set" do
        ENV["AUTH_TOKEN"] = ""
        header "Authorization", "token "
        expect { put "/logs/#{@job_id}", "" }.to raise_error(/token/)
      end

      it "returns 403 if the Authorization header isn't set" do
        response = put "/logs/#{@job_id}", ""
        expect(response.status).to be == 403
      end

      it "returns 403 if the Authorization header is incorrect" do
        header "Authorization", "token not-#{@auth_token}"
        response = put "/logs/#{@job_id}", ""
        expect(response.status).to be == 403
      end
    end
  end
end
