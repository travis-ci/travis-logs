# frozen_string_literal: true

describe Travis::Logs::RedisPool do
  subject(:redis) { described_class.new }
  let(:unpooled_redis) { Redis.new }

  it 'increases the metric for number of operations' do
    expect do
      subject.get('test')
    end.to change { Metriks.timer('redis.operations').count }.by(1)
  end

  it 'forwards operations to redis' do
    subject.set('some-key', 100)
    expect(unpooled_redis.get('some-key')).to eq('100')
  end

  it 'fails when a non-supported operation is called' do
    expect do
      subject.setssss
    end.to raise_error(NoMethodError)
  end

  it 'adds a wait time for the pool checkout' do
    expect do
      subject.get('test')
    end.to change { Metriks.timer('redis.pool.wait').count }.by(1)
  end
end
