require 'travis/logs/helpers/database_table_mapper'

describe Travis::Logs::Helpers::DatabaseTableMapper do
  let(:db) do
    double(
      'db',
      tables: tables,
    )
  end

  let(:logs_schema) do
    [
      [:id, { default: "nextval('logs_id_seq'::regclass)" }]
    ]
  end

  let(:log_parts_schema) do
    [
      [:id, { default: "nextval('log_parts_id_seq'::regclass)" }]
    ]
  end

  let(:tables) { [] }

  subject { described_class.new(db: db) }

  before do
    allow(db).to receive(:schema) do |t|
      [
        [:id, { default: "nextval('#{t}_id_seq'::regclass)" }]
      ]
    end

    allow(db).to receive(:[]) do |q|
      {
        'SELECT min_value, max_value FROM log_parts_id_seq' => [
          {
            min_value: 0,
            max_value: 40
          }
        ],
        'SELECT MAX(id) FROM log_parts' => [
          { max: 4 }
        ],
        'SELECT min_value, max_value FROM logs_id_seq' => [
          {
            min_value: 100,
            max_value: 200
          }
        ],
        'SELECT MAX(id) FROM logs' => [
          { max: 102 }
        ]
      }.fetch(q)
    end
  end

  it 'has a db' do
    expect(subject.send(:db)).to eq(db)
  end

  context 'with no tables detected' do
    let(:tables) { [] }

    it 'creates a mapping' do
      result = subject.run
      expect(result).to_not be_nil
      expect(result).to_not be_empty
    end
  end

  context 'with base tables only' do
    let(:tables) { %w(logs log_parts) }

    it 'creates a mapping' do
      result = subject.run
      expect(result).to_not be_nil
      expect(result).to_not be_empty
    end
  end
end
