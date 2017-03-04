require 'ostruct'
require 'travis/logs'
require 'travis/logs/app'
require 'rack/test'
require 'openssl'

ENV['RACK_ENV'] = 'test'

describe Travis::Logs::App do
  include Rack::Test::Methods

  def app
    Travis::Logs::App.new(auth_token: auth_token)
  end

  let(:pusher) { double(:pusher) }
  let(:existence) { Travis::Logs::Existence.new }
  let(:database) { double(:database) }
  let(:log_part_service) { double(:log_part_service) }
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
    allow_any_instance_of(described_class)
      .to receive(:process_log_part_service).and_return(log_part_service)
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
      body = JSON.parse(response.body)
      %w(uptime greeting now pong version).each do |key|
        expect(body).to include(key)
        expect(body[key]).to_not be_nil
      end
    end
  end

  describe 'POST /pusher/existence' do
    it 'sets proper properties on channel' do
      expect(existence.occupied?('foo')).to be nil
      expect(existence.occupied?('bar')).to be nil

      webhook = OpenStruct.new(valid?: true, events: [
                                 { 'name' => 'channel_occupied', 'channel' => 'foo' },
                                 { 'name' => 'channel_vacated',  'channel' => 'bar' }
                               ])
      expect(pusher).to receive(:webhook) do |request|
        request.path_info == '/pusher/existence'
        webhook
      end

      response = post '/pusher/existence'
      expect(response.status).to eq(204)

      expect(existence.occupied?('foo')).to eq('true')
      expect(existence.occupied?('bar')).to be nil

      webhook = OpenStruct.new(valid?: true, events: [
                                 { 'name' => 'channel_vacated', 'channel' => 'foo' },
                                 { 'name' => 'channel_occupied', 'channel' => 'bar' }
                               ])
      expect(pusher).to receive(:webhook) do |request|
        request.path_info == '/pusher/existence'
        webhook
      end

      response = post '/pusher/existence'
      expect(response.status).to eq(204)

      expect(existence.occupied?('foo')).to be nil
      expect(existence.occupied?('bar')).to eq('true')
    end

    it 'responds with 401 with invalid webhook' do
      webhook = OpenStruct.new(valid?: false)
      expect(pusher).to receive(:webhook) do |request|
        request.path_info == '/pusher/existence'
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
      allow(database).to receive(:set_log_content)
      allow(database).to receive(:log_id_for_job_id)
        .with(anything).and_return(nil)
      allow(database).to receive(:log_id_for_job_id)
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

      it 'returns 204' do
        response = put "/logs/#{@job_id}"
        expect(response.status).to be == 200
      end

      it "creates the log if it doesn't exist" do
        result = { id: @log_id + 1, job_id: @job_id + 1, content: '' }
        allow(database).to receive(:log_for_job_id)
          .with(@job_id + 1)
          .and_return(result.merge(aggregated_at: Time.now.utc))
        expect(database).to receive(:create_log).with(@job_id + 1)
          .and_return(result)

        response = put "/logs/#{@job_id + 1}"
        expect(response.status).to be == 200
      end

      it 'tells the database to set the log content' do
        expect(database).to receive(:set_log_content)
          .with(@log_id, 'hello, world', removed_by: nil)
        put "/logs/#{@job_id}", 'hello, world'
      end

      it 'does not set log content if the given body was empty' do
        expect(database).to receive(:set_log_content)
          .with(@log_id, nil, removed_by: nil)
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
      rsa_private_key = <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA1cM1oaP1JLlB6iEdIbTAvToiydfypq+K/H3tSlRfoY1k/wIn
QRbF5XHBdgMJvLPYdqPzbzE5l+vThgk20RIsAV8DYd1nEH+rSnZaX3Q48JKi0A19
bw/5TrW7URrk/peKfqDO0f5tS+/wRnwdrJFhqpSlQkaC6aTcCM/8RoDCLG8m1+0B
F3QDQcjl1HL2sFeXI0F7pdW59s+1exc324TfWoWXfGDa74bsI+UDKKsUGvg+St7f
f5Y4NWtM1OIjqrWYt6wtNyhIC/Ru6Uboe81p6EIIq1yX2Lb961BP4EXeae9Nj/aQ
CzBNUsFPSKAHRdHrOhAuMgg5xmke8cAOF3SIoQIDAQABAoIBABMINV815N6nK+o3
lotot3xhj7Ve57jVik9euuDSUE1m9GYMAAi4iVgbX7ktHhHSBWTSxhrRTCptkcCu
U1YcAxUAK6Hr/4Aljc+sZ/F1vJgWxi419UQNLQpH/eyDs33Dak5J7QAfYgXP0BnG
dTHnI8X3RBt5gbBhwEF8mx5/2knwVd+0sMQm0g+bZMUOD7bEt0aaGk+oSQVzUL0B
MPRLNTkJj/7gzDjzMy2SrWpdPQ+BuTX91sq32ymGARAOssd+mum3/2R8YZsAAqfP
DV6uLwSYJJ1wiy9s2A9MtUuOEU1NT2kiU3iRehgzFMuvjdsFo2j9Vqh/lyuZuft8
5dPqmxECgYEA7vKUn14J4nORPpkV1vhsykHizhLiiY7SYfoUn2CEHCVLIARHoAGp
Y7QgSoOAxm+2NQO/Equ8rMtaGobcPyn8S0u3v/pZNL591B3v7fXVXkrT6dRryQqp
To2TdQBdqe2AtNEQAUA0XmnuVpRcKvL6wbzIbfouj/rpGlqUgDkSGJUCgYEA5QSD
qfJK1lWAmQqKUstVirSlfj7Ro+Ra8XorRJLc5T4k4S8lgqEGX46HpnrXwmH/zNVF
aK87KuupR3LuS8WWfj0DsI/IclCu0kIHj3DMOrNcFFQPXCpnvEIyDtpRue6bZ15v
Xya5p9lff1x1ogjkewWmLm9Lh1iZyi+XP70cEN0CgYAcmHVG2TcvnYr9Rc7CSjqi
vd3JsaLguXHd/dKn/CHzSFdEPp7fvDMsVmsi37fyh33zvD4KmvjaaP+gexEykfC6
hhY4aFpyoHVohCipfqkJPsU7j4tSpO78Ep9Z+jA7XMvxV6+lpqxdvCmkvN6G2Us/
EjueRbl6y5lH6R0qdyn+PQKBgA1Xh/wcm3OFI6rGzGwqYF9mSsXiDwCHSy0KOv8R
t0C7sBZWUs8bZm2mtgxi17MBVo+uVQ7WNpI3jHMXJP7REgVktJRSrBDM1oJ1Sk92
+M7qqBCfHQ33gnebO6NV4LD+T5tkCwT2EpbOuRuIXWoFLppkJ9xIq5PE+6ClyR/z
enEZAoGBAJajfJIEi0GFfRcw1USpZlNVy1IlKeB1CO5WOFYw9lIkFTnlWzOsJ6J6
pGtarhuDVtIIXpS8tlrToQSUdMlzKqwqk9g6cm+vPYdd+yGNzdWBADURqeZjzA0Q
oRLuY9cp8DkPGlJ2P7sxugWnMyoIUEXIVwAwWJJ/Qwd2nOUMbYKr
-----END RSA PRIVATE KEY-----
EOF

      @rsa_key = OpenSSL::PKey.read(rsa_private_key)
      ENV['JWT_RSA_PUBLIC_KEY'] = @rsa_key.public_key.to_pem

      @job_id = 1
      @log_id = 456

      allow(log_part_service).to receive(:run).with(
        'id' => @job_id,
        'log' => 'fafafaf',
        'number' => '1',
        'final' => false
      ).and_return(nil)
    end

    context 'with valid authorization header' do
      before do
        payload = { sub: @job_id.to_s }
        token = JWT.encode(payload, @rsa_key, 'RS512')
        header 'Authorization', "Bearer #{token}"
      end

      it 'returns 204' do
        body = JSON.dump(
          '@type' => 'log_part',
          'final' => false,
          'content' => Base64.encode64('fafafaf'),
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
        token = JWT.encode(payload, @rsa_key, 'RS512')
        header 'Authorization', "Bearer #{token}"
      end

      it 'returns 403' do
        response = put "/log-parts/#{@job_id}/1", ''
        expect(response.status).to be == 403
      end
    end
  end
end
