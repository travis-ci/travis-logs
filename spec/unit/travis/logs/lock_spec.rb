# frozen_string_literal: true

describe Travis::Logs::Lock do
  let(:lock_options) { lock_config.merge(url: redis_url) }
  let(:lock_config) { { official: :config, very: :srs } }
  let(:redis_url) { 'redis://very.memory.example.com' }

  subject do
    described_class.new('flarp.flub', {})
  end

  before :each do
    allow(subject).to receive(:lock_options).and_return(lock_options)
    allow(subject).to receive(:base_lock_config).and_return(lock_config)
    allow(subject).to receive(:redis_url).and_return(redis_url)
  end

  it 'locks exclusively' do
    expect(subject.exclusive { :huh }).to eq :huh
  end

  [
    [{}, {}],
    [
      nil,
      { official: :config, very: :srs }
    ],
    [
      { unofficial: :config, such: :rogue },
      { unofficial: :config, such: :rogue }
    ],
    [
      { unofficial: :config, such: :rogue, strategy: :redis },
      { unofficial: :config, such: :rogue, strategy: :redis,
        url: 'redis://very.memory.example.com' }
    ]
  ].each do |options, normalized_options|
    it "normalizes locking options #{options.inspect}" do
      expect(subject.send(:normalized_locking_options, options: options))
        .to eq normalized_options
    end
  end
end
