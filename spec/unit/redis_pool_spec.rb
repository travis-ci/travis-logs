require 'travis/redis_pool'

describe Travis::RedisPool do
  let(:redis) { Travis::RedisPool.new }
  let(:unpooled_redis) { Redis.new }

  it 'increases the metric for number of operations' do
    expect do
      redis.get('test')
    end.to change { Metriks.timer('redis.operations').count }.by(1)
  end

  it 'forwards operations to redis' do
    redis.set('some-key', 100)
    expect(unpooled_redis.get('some-key')).to eql '100'
  end

  it 'fails when a non-supported operation is called' do
    expect { redis.setssss }.to raise_error(NoMethodError)
  end

  it 'adds a wait time for the pool checkout' do
    expect do
      redis.get('test')
    end.to change { Metriks.timer('redis.pool.wait').count }.by(1)
  end
end
