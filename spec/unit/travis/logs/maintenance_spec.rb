# frozen_string_literal: true

describe Travis::Logs::Maintenance do
  let(:redis) { double(Travis::Logs::RedisPool) }
  let(:expiry) { 1.minute }

  subject do
    described_class.new(redis: redis, expiry: expiry)
  end

  before do
    allow(redis).to receive(:setex)
      .with(described_class::MAINTENANCE_KEY, expiry, 'on')
    allow(redis).to receive(:del).with(described_class::MAINTENANCE_KEY)
  end

  it 'yields with maintenance on' do
    state = { foo: 1 }
    subject.with_maintenance_on do
      state[:foo] = 0
    end

    expect(state[:foo]).to eq 0
  end

  it 'tells when enabled' do
    allow(redis).to receive(:get).with(described_class::MAINTENANCE_KEY)
                                 .and_return('huh')

    expect(subject.enabled?).to be false

    allow(redis).to receive(:get).with(described_class::MAINTENANCE_KEY)
                                 .and_return('on')

    expect(subject.enabled?).to be true
  end

  it 'restricts when enabled' do
    allow(redis).to receive(:get).with(described_class::MAINTENANCE_KEY)
                                 .and_return('on')
    allow(redis).to receive(:ttl).with(described_class::MAINTENANCE_KEY)
                                 .and_return(4)

    expect { subject.restrict! }
      .to raise_error(Travis::Logs::UnderMaintenanceError)
  end

  it 'does not restrict when disabled' do
    allow(redis).to receive(:get).with(described_class::MAINTENANCE_KEY)
                                 .and_return(nil)

    expect { subject.restrict! }.to_not raise_error
  end
end
