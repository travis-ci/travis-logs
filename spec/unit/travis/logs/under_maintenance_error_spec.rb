# frozen_string_literal: true

describe Travis::Logs::UnderMaintenanceError do
  let(:ttl) { rand(4..42) }
  subject { described_class.new(ttl) }

  it 'has a ttl' do
    expect(subject.ttl).to eq ttl
  end

  it 'has an http_status' do
    expect(subject.http_status).to eq 503
  end

  it 'has a message' do
    expect(subject.message).to eq("under maintenance for the next #{ttl}s")
  end
end
