require 'travis/logs/sidekiq'

describe Travis::Logs::Sidekiq do
  before do
    allow(::Sidekiq).to receive(:redis)
    allow(::Sidekiq::RedisConnection).to receive(:create)
  end

  it 'sets up sidekiq' do
    expect(described_class.setup).to eql(:alldone)
  end
end
