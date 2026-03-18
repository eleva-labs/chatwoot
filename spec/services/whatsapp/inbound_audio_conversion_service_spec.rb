require 'rails_helper'

RSpec.describe Whatsapp::InboundAudioConversionService do
  let(:service) { described_class.new }

  describe '.convert_if_voice' do
    it 'delegates to instance method' do
      downloaded_file = double('downloaded_file',
                               original_filename: 'audio.mp3',
                               content_type: 'audio/mpeg')

      expect_any_instance_of(described_class).to receive(:convert_if_voice).with(downloaded_file, 'audio')
      described_class.convert_if_voice(downloaded_file, 'audio')
    end
  end

  describe '#convert_if_voice' do
    context 'when file is OGG voice message' do
      let(:downloaded_file) do
        double('downloaded_file',
               original_filename: 'audio.oga',
               content_type: 'audio/ogg; codecs=opus',
               rewind: nil)
      end

      it 'attempts conversion and returns M4A attributes on success' do
        allow(service).to receive(:verify_ffmpeg_availability)
        m4a_output = Tempfile.new(['converted', '.m4a'])
        m4a_output.write('fake m4a data')
        m4a_output.rewind
        allow(service).to receive(:convert_ogg_to_m4a).and_return(m4a_output)

        result = service.convert_if_voice(downloaded_file, 'voice')

        expect(result[:content_type]).to eq('audio/mp4')
        expect(result[:filename]).to eq('audio.m4a')
        expect(result[:io]).to eq(m4a_output)

        m4a_output.close
        m4a_output.unlink
      end

      it 'falls back to original file when FFmpeg fails' do
        allow(service).to receive(:convert_ogg_to_m4a).and_raise(StandardError.new('FFmpeg failed'))

        result = service.convert_if_voice(downloaded_file, 'voice')
        expect(result[:content_type]).to eq('audio/ogg; codecs=opus')
        expect(result[:io]).to eq(downloaded_file)
      end
    end

    context 'when file has audio/ogg content type' do
      let(:downloaded_file) do
        double('downloaded_file',
               original_filename: 'voice.ogg',
               content_type: 'audio/ogg')
      end

      it 'detects OGG content type as needing conversion' do
        expect(service.send(:should_convert?, downloaded_file, 'voice')).to be true
      end
    end

    context 'when file has audio/opus content type' do
      let(:downloaded_file) do
        double('downloaded_file',
               original_filename: 'voice.opus',
               content_type: 'audio/opus')
      end

      it 'detects Opus content type as needing conversion' do
        expect(service.send(:should_convert?, downloaded_file, 'audio')).to be true
      end
    end

    context 'when file is not OGG' do
      let(:downloaded_file) do
        double('downloaded_file',
               original_filename: 'audio.mp3',
               content_type: 'audio/mpeg')
      end

      it 'returns original attributes unchanged' do
        result = service.convert_if_voice(downloaded_file, 'audio')

        expect(result[:content_type]).to eq('audio/mpeg')
        expect(result[:filename]).to eq('audio.mp3')
        expect(result[:io]).to eq(downloaded_file)
      end
    end

    context 'when message type is not audio/voice' do
      let(:downloaded_file) do
        double('downloaded_file',
               original_filename: 'image.jpg',
               content_type: 'image/jpeg')
      end

      it 'returns original attributes unchanged' do
        result = service.convert_if_voice(downloaded_file, 'image')
        expect(result[:io]).to eq(downloaded_file)
        expect(result[:content_type]).to eq('image/jpeg')
      end
    end

    context 'when FFmpeg times out' do
      let(:downloaded_file) do
        double('downloaded_file',
               original_filename: 'voice.oga',
               content_type: 'audio/ogg',
               rewind: nil)
      end

      it 'falls back to original file on timeout' do
        allow(service).to receive(:convert_ogg_to_m4a).and_raise(Timeout::Error)

        result = service.convert_if_voice(downloaded_file, 'voice')
        expect(result[:content_type]).to eq('audio/ogg')
        expect(result[:io]).to eq(downloaded_file)
      end
    end
  end

  describe '#should_convert?' do
    context 'with voice message type and OGG content' do
      let(:file) { double('file', content_type: 'audio/ogg') }

      it 'returns true' do
        expect(service.send(:should_convert?, file, 'voice')).to be true
      end
    end

    context 'with audio message type and OGG content' do
      let(:file) { double('file', content_type: 'audio/ogg') }

      it 'returns true' do
        expect(service.send(:should_convert?, file, 'audio')).to be true
      end
    end

    context 'with image message type' do
      let(:file) { double('file', content_type: 'audio/ogg') }

      it 'returns false' do
        expect(service.send(:should_convert?, file, 'image')).to be false
      end
    end

    context 'with voice message type and MP3 content' do
      let(:file) { double('file', content_type: 'audio/mpeg') }

      it 'returns false' do
        expect(service.send(:should_convert?, file, 'voice')).to be false
      end
    end

    context 'with audio/ogg; codecs=opus content type' do
      let(:file) { double('file', content_type: 'audio/ogg; codecs=opus') }

      it 'returns true after normalization' do
        expect(service.send(:should_convert?, file, 'voice')).to be true
      end
    end
  end

  describe '#normalize_content_type' do
    it 'normalizes whitespace around semicolons' do
      expect(service.send(:normalize_content_type, 'audio/ogg; codecs=opus')).to eq('audio/ogg;codecs=opus')
    end

    it 'downcases content type' do
      expect(service.send(:normalize_content_type, 'Audio/OGG')).to eq('audio/ogg')
    end

    it 'handles blank content type' do
      expect(service.send(:normalize_content_type, nil)).to eq('')
      expect(service.send(:normalize_content_type, '')).to eq('')
    end
  end

  describe '#replace_extension' do
    it 'replaces .oga with .m4a' do
      expect(service.send(:replace_extension, 'audio.oga', '.m4a')).to eq('audio.m4a')
    end

    it 'replaces .ogg with .m4a' do
      expect(service.send(:replace_extension, 'voice.ogg', '.m4a')).to eq('voice.m4a')
    end

    it 'handles blank filename' do
      expect(service.send(:replace_extension, nil, '.m4a')).to eq('voice_message.m4a')
      expect(service.send(:replace_extension, '', '.m4a')).to eq('voice_message.m4a')
    end

    it 'handles filename without extension' do
      expect(service.send(:replace_extension, 'audio', '.m4a')).to eq('audio.m4a')
    end
  end

  describe '#verify_ffmpeg_availability' do
    context 'when FFmpeg is available' do
      before do
        allow(service).to receive(:system).with('which ffmpeg > /dev/null 2>&1').and_return(true)
      end

      it 'does not raise error' do
        expect { service.send(:verify_ffmpeg_availability) }.not_to raise_error
      end
    end

    context 'when FFmpeg is not available' do
      before do
        allow(service).to receive(:system).with('which ffmpeg > /dev/null 2>&1').and_return(false)
      end

      it 'raises error' do
        expect { service.send(:verify_ffmpeg_availability) }
          .to raise_error('FFmpeg is not installed. Required for inbound voice message conversion.')
      end
    end
  end

  describe '#cleanup_temp_file' do
    it 'closes and unlinks a temp file' do
      temp_file = double('temp_file')
      allow(temp_file).to receive(:respond_to?).with(:close).and_return(true)
      allow(temp_file).to receive(:respond_to?).with(:unlink).and_return(true)
      allow(temp_file).to receive(:closed?).and_return(false)
      allow(temp_file).to receive(:close)
      allow(temp_file).to receive(:unlink)

      service.send(:cleanup_temp_file, temp_file)

      expect(temp_file).to have_received(:close)
      expect(temp_file).to have_received(:unlink)
    end

    it 'does not close an already closed file' do
      temp_file = double('temp_file')
      allow(temp_file).to receive(:respond_to?).with(:close).and_return(true)
      allow(temp_file).to receive(:respond_to?).with(:unlink).and_return(true)
      allow(temp_file).to receive(:closed?).and_return(true)
      allow(temp_file).to receive(:close)
      allow(temp_file).to receive(:unlink)

      service.send(:cleanup_temp_file, temp_file)

      expect(temp_file).not_to have_received(:close)
    end

    it 'handles cleanup errors gracefully' do
      temp_file = double('temp_file')
      allow(temp_file).to receive(:respond_to?).with(:close).and_return(true)
      allow(temp_file).to receive(:closed?).and_return(false)
      allow(temp_file).to receive(:close).and_raise(StandardError.new('Cleanup failed'))
      expect(Rails.logger).to receive(:warn).with(/\[WHAPI_INBOUND_AUDIO\] Failed to cleanup temp file/)

      expect { service.send(:cleanup_temp_file, temp_file) }.not_to raise_error
    end

    it 'skips nil files' do
      expect { service.send(:cleanup_temp_file, nil) }.not_to raise_error
    end
  end

  describe 'constants' do
    it 'defines OGG content types' do
      expect(described_class::OGG_CONTENT_TYPES).to contain_exactly(
        'audio/ogg', 'audio/opus', 'audio/ogg;codecs=opus'
      )
    end

    it 'defines FFmpeg timeout' do
      expect(described_class::FFMPEG_TIMEOUT).to eq(60)
    end
  end
end
