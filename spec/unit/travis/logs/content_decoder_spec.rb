# frozen_string_literal: true

describe Travis::Logs::ContentDecoder do
  subject { described_class }

  context 'when base64-encoded' do
    let(:ascii_entry) do
      {
        'log' => Base64.strict_encode64('hello to the world'),
        'encoding' => 'base64'
      }
    end

    let(:bytemess_entry) do
      {
        'log' => Base64.strict_encode64("hello to the world\xf1\xe5\x7a!"),
        'encoding' => 'base64'
      }
    end

    it 'passes through ascii bytes unaltered' do
      expect(subject.decode_content(ascii_entry))
        .to eq('hello to the world')
    end

    it 'cleans out messy bytes' do
      expect(subject.decode_content(bytemess_entry))
        .to eq('hello to the worldz!')
    end

    it 'encodes to UTF-8' do
      expect(subject.decode_content(ascii_entry).encoding)
        .to eq(Encoding::UTF_8)
      expect(subject.decode_content(bytemess_entry).encoding)
        .to eq(Encoding::UTF_8)
    end
  end

  context 'when unencoded' do
    let(:ascii_entry) do
      {
        'log' => 'hello to the world'
      }
    end

    let(:bytemess_entry) do
      {
        'log' => "hello to the world\xf1\xe5\x7a!"
      }
    end

    it 'passes through ascii bytes unaltered' do
      expect(subject.decode_content(ascii_entry))
        .to eq('hello to the world')
    end

    it 'cleans out messy bytes' do
      expect(subject.decode_content(bytemess_entry))
        .to eq('hello to the worldz!')
    end

    it 'encodes to UTF-8' do
      expect(subject.decode_content(ascii_entry).encoding)
        .to eq(Encoding::UTF_8)
      expect(subject.decode_content(bytemess_entry).encoding)
        .to eq(Encoding::UTF_8)
    end
  end
end
