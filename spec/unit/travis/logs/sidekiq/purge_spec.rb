require 'travis/logs/sidekiq/purge'

describe Travis::Logs::Sidekiq::Purge do
  it 'has a perform method' do
    expect(subject).to respond_to(:perform)
  end
end
