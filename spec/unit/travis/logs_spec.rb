describe Travis::Logs do
  it 'autoloads Aggregate' do
    expect(Travis::Logs::Aggregate).to_not be_nil
  end

  it 'autoloads App' do
    expect(Travis::Logs::App).to_not be_nil
  end

  it 'autoloads Config' do
    expect(Travis::Logs::Config).to_not be_nil
  end

  it 'autoloads Existence' do
    expect(Travis::Logs::Existence).to_not be_nil
  end

  it 'autoloads Receive' do
    expect(Travis::Logs::Receive).to_not be_nil
  end

  it 'autoloads Sidekiq' do
    expect(Travis::Logs::Sidekiq).to_not be_nil
  end
end
