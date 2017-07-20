# frozen_string_literal: true

require 'ostruct'
require 'rack/test'
require 'openssl'

describe Travis::Logs::App do
  include Rack::Test::Methods

  def app
    Travis::Logs::App.new(auth_token: auth_token)
  end

  let(:pusher) { double(:pusher) }
  let(:existence) { Travis::Logs::Existence.new }
  let(:database) { double(:database) }
  let(:auth_token) { 'very-secret' }

  before do
    existence.vacant!('foo')
    existence.vacant!('bar')
    allow_any_instance_of(described_class)
      .to receive(:existence).and_return(existence)
    allow_any_instance_of(described_class)
      .to receive(:pusher).and_return(pusher)
    allow_any_instance_of(described_class)
      .to receive(:database).and_return(database)
  end

  describe 'GET /uptime' do
    before do
      allow(database).to receive(:now) { Time.now.utc }
    end

    it 'returns 204' do
      response = get '/uptime'
      expect(response.status).to eq(200)
    end

    it 'contains uptime, greeting, now, pong, and version' do
      response = get '/uptime'
      body = MultiJson.load(response.body)
      %w[uptime greeting now pong version].each do |key|
        expect(body).to include(key)
        expect(body[key]).to_not be_nil
      end
    end
  end

  describe 'POST /pusher/existence' do
    it 'sets proper properties on channel' do
      expect(existence.occupied?('foo')).to be false
      expect(existence.occupied?('bar')).to be false

      webhook = OpenStruct.new(valid?: true, events: [
                                 { 'name' => 'channel_occupied', 'channel' => 'foo' },
                                 { 'name' => 'channel_vacated',  'channel' => 'bar' }
                               ])
      expect(pusher).to receive(:webhook) do |request|
        expect(request.path_info).to eq('/pusher/existence')
        webhook
      end

      response = post '/pusher/existence'
      expect(response.status).to eq(204)

      expect(existence.occupied?('foo')).to be true
      expect(existence.occupied?('bar')).to be false

      webhook = OpenStruct.new(valid?: true, events: [
                                 { 'name' => 'channel_vacated', 'channel' => 'foo' },
                                 { 'name' => 'channel_occupied', 'channel' => 'bar' }
                               ])
      expect(pusher).to receive(:webhook) do |request|
        expect(request.path_info).to eq('/pusher/existence')
        webhook
      end

      response = post '/pusher/existence'
      expect(response.status).to eq(204)

      expect(existence.occupied?('foo')).to be false
      expect(existence.occupied?('bar')).to be true
    end

    it 'responds with 401 with invalid webhook' do
      webhook = OpenStruct.new(valid?: false)
      expect(pusher).to receive(:webhook) do |request|
        expect(request.path_info).to eq('/pusher/existence')
        webhook
      end

      response = post '/pusher/existence'
      expect(response.status).to eq(401)
    end
  end

  describe 'PUT /logs/:id' do
    before do
      @job_id = 123
      @log_id = 234

      allow(database).to receive(:transaction) { |&b| b.call }
      allow(database).to receive(:log_id_for_job_id)
        .with(anything).and_return(nil)
      allow(database).to receive(:cached_log_id_for_job_id)
        .with(anything).and_return(nil)
      allow(database).to receive(:log_id_for_job_id)
        .with(@job_id).and_return(@log_id)
      allow(database).to receive(:cached_log_id_for_job_id)
        .with(@job_id).and_return(@log_id)
      allow(database).to receive(:log_for_job_id)
        .with(@job_id)
        .and_return(
          job_id: @job_id,
          id: @log_id,
          content: '',
          aggregated_at: Time.now.utc
        )
    end

    context 'with correct authentication' do
      before do
        header 'Authorization', "token #{auth_token}"
      end

      it 'returns 200' do
        allow(database).to receive(:set_log_content)
          .and_return([{ id: @log_id, job_id: @job_id, content: '' }])
        response = put "/logs/#{@job_id}"
        expect(response.status).to be == 200
      end

      it "creates the log if it doesn't exist" do
        result = { id: @log_id + 1, job_id: @job_id + 1, content: '' }
        expect(database).to receive(:create_log).with(@job_id + 1)
                                                .and_return(@log_id + 1)
        expect(database).to receive(:set_log_content)
          .with(@log_id + 1, nil, removed_by: nil)
          .and_return([result])

        response = put "/logs/#{@job_id + 1}"
        expect(response.status).to be == 200
      end

      it 'tells the database to set the log content' do
        expect(database).to receive(:set_log_content)
          .with(@log_id, 'hello, world', removed_by: nil)
          .and_return(
            [{ id: @log_id, job_id: @job_id, content: 'hello, world' }]
          )
        put "/logs/#{@job_id}", 'hello, world'
      end

      it 'does not set log content if the given body was empty' do
        expect(database).to receive(:set_log_content)
          .with(@log_id, nil, removed_by: nil)
          .and_return(
            [{ id: @log_id, job_id: @job_id, content: 'hello, world' }]
          )
        put "/logs/#{@job_id}", ''
      end
    end

    context 'without an empty auth_token' do
      let(:auth_token) { '' }

      it "returns 500 if the auth token isn't set" do
        header 'Authorization', 'token '
        response = put "/logs/#{@job_id}", ''
        expect(response.status).to be == 500
      end
    end

    it "returns 403 if the Authorization header isn't set" do
      response = put "/logs/#{@job_id}", ''
      expect(response.status).to be == 403
    end

    it 'returns 403 if the Authorization header is incorrect' do
      header 'Authorization', "token not-#{auth_token}"
      response = put "/logs/#{@job_id}", ''
      expect(response.status).to be == 403
    end
  end

  describe 'PUT /log-parts/:job_id/:log_part_id' do
    before do
      @job_id = 1
      @log_id = 456

      allow(Travis::Logs::Sidekiq::LogParts).to receive(:perform_async).with(
        'id' => @job_id,
        'log' => Base64.strict_encode64('fafafaf'),
        'encoding' => 'base64',
        'number' => '1',
        'final' => false
      ).and_return(nil)
    end

    context 'with valid authorization header' do
      before do
        payload = { sub: @job_id.to_s }
        token = JWT.encode(payload, SpecHelper.rsa_key, 'RS512')
        header 'Authorization', "Bearer #{token}"
      end

      it 'returns 204' do
        body = MultiJson.dump(
          '@type' => 'log_part',
          'final' => false,
          'content' => Base64.strict_encode64('fafafaf'),
          'encoding' => 'base64'
        )
        response = put "/log-parts/#{@job_id}/1", body
        expect(response.status).to be == 204
      end
    end

    context 'with no authorization header' do
      it 'returns 403' do
        response = put "/log-parts/#{@job_id}/1", ''
        expect(response.status).to be == 403
      end
    end

    context 'with invalid authorization header' do
      it 'returns 403' do
        header 'Authorization', 'Bearer fafafafafaf'

        response = put "/log-parts/#{@job_id}/1", ''
        expect(response.status).to be == 403
      end
    end

    context 'with invalid JWT subject' do
      before do
        payload = { sub: (@job_id + 1).to_s }
        token = JWT.encode(payload, SpecHelper.rsa_key, 'RS512')
        header 'Authorization', "Bearer #{token}"
      end

      it 'returns 403' do
        response = put "/log-parts/#{@job_id}/1", ''
        expect(response.status).to be == 403
      end
    end
  end

  describe 'POST /log-parts/multi' do
    let :decoded_payload do
      [
        {
          'encoding' => 'base64',
          'id' => 1,
          'log' => Base64.strict_encode64('fafafaf'),
          'number' => '1',
          'final' => false
        },
        {
          'encoding' => 'base64',
          'id' => 2,
          'log' => Base64.strict_encode64('fafafaf'),
          'number' => '1',
          'final' => false
        },
        {
          'encoding' => 'base64',
          'id' => 5,
          'log' => Base64.strict_encode64('fafafaf'),
          'number' => '1',
          'final' => false
        }
      ]
    end

    let :unauthorized_request_body do
      [
        { job_id: 1 },
        { job_id: 2 },
        { job_id: 5 }
      ].map do |j|
        j.merge(
          :@type => 'log_part',
          content: Base64.strict_encode64('fafafaf'),
          encoding: 'base64',
          final: false,
          number: '1'
        )
      end
    end

    context 'with no authorization header' do
      it 'returns 403' do
        response = post '/log-parts/multi'
        expect(response.status).to be == 403
      end
    end

    context 'with invalid authorization header' do
      it 'returns 403' do
        header 'Authorization', 'token sig:wat'
        request_body = unauthorized_request_body.map do |j|
          j.merge('tok' => 'fafafaf')
        end
        response = post '/log-parts/multi', MultiJson.dump(request_body)
        expect(response.status).to be == 403
      end
    end

    context 'with valid authorization header' do
      before do
        allow(Travis::Logs::Sidekiq::LogParts)
          .to receive(:perform_async).with(decoded_payload).and_return(nil)
      end

      it 'returns 204' do
        request_body = unauthorized_request_body.map do |j|
          payload = { sub: j[:job_id].to_s }
          j.merge('tok' => JWT.encode(payload, SpecHelper.rsa_key, 'RS512'))
        end

        sig = Digest::SHA1.hexdigest(request_body.map { |j| j['tok'] }.join)
        header 'Authorization', "token sig:#{sig}"
        response = post '/log-parts/multi', MultiJson.dump(request_body)
        expect(response.status).to be == 204
      end
    end

    context 'with unauthorized log part' do
      it 'drops the unauthorized log part and returns 204' do
        request_body = unauthorized_request_body.map do |j|
          payload = { sub: j[:job_id].to_s }
          if j[:job_id] == 1
            j.merge('tok' => 'bogus')
          else
            j.merge('tok' => JWT.encode(payload, SpecHelper.rsa_key, 'RS512'))
          end
        end

        expect(Travis::Logs::Sidekiq::LogParts)
          .to receive(:perform_async)
          .with(decoded_payload.reject { |j| j['id'] == 1 })

        sig = Digest::SHA1.hexdigest(request_body.map { |j| j['tok'] }.join)
        header 'Authorization', "token sig:#{sig}"
        response = post '/log-parts/multi', MultiJson.dump(request_body)
        expect(response.status).to be == 204
      end
    end
  end
end
