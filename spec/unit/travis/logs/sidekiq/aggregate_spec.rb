# frozen_string_literal: true

describe Travis::Logs::Sidekiq::Aggregate do
  let(:log_id) { rand(10_000..19_999) }

  it 'runs #aggregate_log for one log id' do
    expect(subject.send(:aggregate_logs_service))
      .to receive(:aggregate_log).with(log_id)
    subject.perform(log_id)
  end
end
