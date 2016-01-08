require 'travis/logs/investigator'

describe Travis::Logs::Investigator do
  subject do
    described_class.new(
      'fatal_exit',
      /fatal error exit \b(?<code>\d+)/,
      'fatal.%{code}',
      'fatal_error_%{code}'
    )
  end

  context 'when match is found' do
    let :logs do
      <<-EOF
        $ run a thing
        stuff happen
        !!! fatal error exit 137 !!!
      EOF
    end

    it 'returns result with marking' do
      expect(subject.investigate(logs).marking).to eql('fatal.137')
    end

    it 'returns result with label' do
      expect(subject.investigate(logs).label).to eql('fatal_error_137')
    end
  end

  context 'when no match is found' do
    let :logs do
      <<-EOF
        $ run a thing
        stuff happen
        $ all done now
        yey partay
        haha fatal error exit lol nope
      EOF
    end

    it 'returns nil result' do
      expect(subject.investigate(logs)).to be_nil
    end
  end
end
