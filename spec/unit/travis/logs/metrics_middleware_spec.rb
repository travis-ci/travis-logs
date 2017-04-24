# frozen_string_literal: true

describe Travis::Logs::MetricsMiddleware do
  let(:app) { double('app', call: [200, {}, 'hai']) }
  subject { described_class.new(app) }

  it 'measures calls and passes through block result' do
    expect(
      subject.call(
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => '/hai'
      )
    ).to eq [200, {}, 'hai']
  end

  [
    {
      env: { 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/logs/1234' },
      name: 'get.logs_id'
    },
    {
      env: { 'REQUEST_METHOD' => 'POST', 'PATH_INFO' => '/pusher/existence' },
      name: 'post.pusher_existence'
    },
    {
      env: { 'REQUEST_METHOD' => 'POST', 'PATH_INFO' => '/logs/multi' },
      name: 'post.logs_multi'
    },
    {
      env: { 'REQUEST_METHOD' => 'PUT', 'PATH_INFO' => '/log-parts/1234/5678' },
      name: 'put.log_parts_id_id'
    },
    {
      env: { 'REQUEST_METHOD' => 'PUT', 'PATH_INFO' => '/loge/1234/flurb' },
      name: 'unk.unk'
    },
    {
      env: { 'PATH_INFO' => '/wat.,,.,!' },
      name: 'unk.unk'
    }
  ].each do |input|
    it "names timer #{input[:name].inspect} from env" do
      expect(subject.send(:timer_name, input[:env])).to eq input[:name]
    end
  end
end
