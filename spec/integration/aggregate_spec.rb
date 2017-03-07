# frozen_string_literal: true
require 'travis/logs'
require 'travis/logs/helpers/database'
require 'travis/logs/services/aggregate_logs'
require 'travis/logs/services/process_log_part'

describe 'aggregation' do
  let(:pusher_client) do
    double('pusher_client', push: nil, pusher_channel_name: '')
  end

  let(:existence) do
    double('existence', occupied?: nil)
  end

  def db
    Travis::Logs.database_connection.instance_variable_get(:@db)
  end

  def lorem_ipsum_words
    @lorem_ipsum_words ||= File.read(
      File.expand_path('../../lorem_ipsum', __FILE__)
    ).split
  end

  def word_salad(n = 100)
    s = ''
    n.times { s += "#{lorem_ipsum_words.sample} " }
    s + "\n"
  end

  def create_payload(job_id, n)
    {
      'id' => job_id,
      'number' => n,
      'log' => word_salad(10 * (job_id % (n + 1)))
    }
  end

  def populate_logs(pusher_client, existence, count = 100)
    lps = Travis::Logs::Services::ProcessLogPart.new(
      database: nil,
      pusher_client: pusher_client,
      existence: existence
    )

    count.times do |n|
      job_id = 17_321 + n

      100.times do |log_part_n|
        lps.run(create_payload(job_id, log_part_n))
      end

      lps.run(create_payload(job_id, 101).merge('final' => true))
    end
  end

  before do
    Travis::Logs.database_connection = Travis::Logs::Helpers::Database.connect
    Travis.config.logs.intervals[:regular] = 0
    db.run('TRUNCATE log_parts; TRUNCATE logs')
    populate_logs(pusher_client, existence, 100)
  end

  it 'aggregates logs' do
    expect(db[:log_parts].count).to be > 0
    2.times { Travis::Logs::Services::AggregateLogs.run }
    expect(db[:log_parts].count).to eql(0)
  end
end
