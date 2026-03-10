require 'rails_helper'

describe Whatsapp::ImageConversionService do
  let(:account) { create(:account) }
  let(:whatsapp_channel) do
    ch = build(:channel_whatsapp, account: account, provider: 'whapi', validate_provider_config: false, sync_templates: false)
    ch.define_singleton_method(:validate_provider_config) { true }
    ch.define_singleton_method(:sync_templates) { nil }
    ch.save!(validate: false)
    ch
  end
  let(:inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, contact: contact, inbox: inbox, account: account) }
  let(:message) { create(:message, conversation: conversation, account: account) }

  let(:service) { described_class.new }

  describe '.convert_if_needed' do
    it 'delegates to instance method' do
      attachment = double('attachment')
      expect_any_instance_of(described_class).to receive(:convert_if_needed).with(attachment)
      described_class.convert_if_needed(attachment)
    end
  end

  describe '#convert_if_needed' do
    context 'when attachment does not need conversion' do
      let(:attachment) do
        attachment = message.attachments.build(account_id: account.id, file_type: :image)
        attachment.file.attach(
          io: StringIO.new('jpeg content'),
          filename: 'test.jpg',
          content_type: 'image/jpeg'
        )
        attachment.save!
        attachment
      end

      it 'returns original content and content type without conversion' do
        result = service.convert_if_needed(attachment)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[1]).to eq('image/jpeg')
      end
    end

    context 'when attachment is HEIC image' do
      let(:attachment) do
        attachment = message.attachments.build(account_id: account.id, file_type: :image)
        attachment.file.attach(
          io: StringIO.new('heic content'),
          filename: 'photo.heic',
          content_type: 'image/heic'
        )
        attachment.save!
        attachment
      end

      before do
        allow(service).to receive(:should_convert?).and_return(true)
        allow(service).to receive(:cleanup_temp_files)
      end

      it 'converts and returns JPEG content with correct content type' do
        temp_file = double('temp_file', path: '/tmp/test_file')
        converted_file = double('converted_file', path: '/tmp/converted_file')
        allow(service).to receive(:download_attachment).and_return(temp_file)
        allow(service).to receive(:convert_heic_to_jpeg).and_return(converted_file)
        allow(File).to receive(:binread).with('/tmp/converted_file').and_return('fake_jpeg_bytes')

        result = service.convert_if_needed(attachment)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[0]).to eq('fake_jpeg_bytes')
        expect(result[1]).to eq('image/jpeg')
      end

      it 'falls back to original on conversion error' do
        allow(service).to receive(:download_attachment).and_raise(StandardError.new('Conversion failed'))

        result = service.convert_if_needed(attachment)

        expect(result).to be_an(Array)
        expect(result[1]).to eq('image/heic')
      end
    end

    context 'when attachment is HEIF image' do
      let(:attachment) do
        attachment = message.attachments.build(account_id: account.id, file_type: :image)
        attachment.file.attach(
          io: StringIO.new('heif content'),
          filename: 'photo.heif',
          content_type: 'image/heif'
        )
        attachment.save!
        attachment
      end

      it 'detects HEIF as needing conversion' do
        expect(service.send(:should_convert?, attachment)).to be true
      end
    end

    context 'when attachment is HEIC sequence (live photo)' do
      let(:attachment) do
        attachment = message.attachments.build(account_id: account.id, file_type: :image)
        attachment.file.attach(
          io: StringIO.new('heic sequence'),
          filename: 'live.heic',
          content_type: 'image/heic-sequence'
        )
        attachment.save!
        attachment
      end

      it 'detects HEIC sequence as needing conversion' do
        expect(service.send(:should_convert?, attachment)).to be true
      end
    end
  end

  describe '#should_convert?' do
    context 'when attachment is not an image' do
      let(:attachment) do
        attachment = message.attachments.build(account_id: account.id, file_type: :audio)
        attachment.file.attach(
          io: StringIO.new('audio content'),
          filename: 'test.mp3',
          content_type: 'audio/mpeg'
        )
        attachment.save!
        attachment
      end

      it 'returns false' do
        expect(service.send(:should_convert?, attachment)).to be false
      end
    end

    context 'when attachment is a regular image' do
      let(:attachment) do
        attachment = message.attachments.build(account_id: account.id, file_type: :image)
        attachment.file.attach(
          io: StringIO.new('image content'),
          filename: filename,
          content_type: content_type
        )
        attachment.save!
        attachment
      end

      context 'with JPEG format' do
        let(:filename) { 'test.jpg' }
        let(:content_type) { 'image/jpeg' }

        it 'returns false' do
          expect(service.send(:should_convert?, attachment)).to be false
        end
      end

      context 'with PNG format' do
        let(:filename) { 'test.png' }
        let(:content_type) { 'image/png' }

        it 'returns false' do
          expect(service.send(:should_convert?, attachment)).to be false
        end
      end

      context 'with WebP format' do
        let(:filename) { 'test.webp' }
        let(:content_type) { 'image/webp' }

        it 'returns false' do
          expect(service.send(:should_convert?, attachment)).to be false
        end
      end

      context 'with HEIC format' do
        let(:filename) { 'photo.heic' }
        let(:content_type) { 'image/heic' }

        it 'returns true' do
          expect(service.send(:should_convert?, attachment)).to be true
        end
      end

      context 'with HEIF format' do
        let(:filename) { 'photo.heif' }
        let(:content_type) { 'image/heif' }

        it 'returns true' do
          expect(service.send(:should_convert?, attachment)).to be true
        end
      end

      context 'with HEIC sequence format' do
        let(:filename) { 'live.heic' }
        let(:content_type) { 'image/heic-sequence' }

        it 'returns true' do
          expect(service.send(:should_convert?, attachment)).to be true
        end
      end

      context 'with HEIF sequence format' do
        let(:filename) { 'live.heif' }
        let(:content_type) { 'image/heif-sequence' }

        it 'returns true' do
          expect(service.send(:should_convert?, attachment)).to be true
        end
      end
    end

    context 'when attachment file is not attached' do
      let(:attachment) { message.attachments.build(account_id: account.id, file_type: :image) }

      it 'returns false' do
        expect(service.send(:should_convert?, attachment)).to be false
      end
    end
  end

  describe '#download_attachment' do
    let(:attachment) do
      attachment = message.attachments.build(account_id: account.id, file_type: :image)
      attachment.file.attach(
        io: StringIO.new('image content'),
        filename: 'photo.heic',
        content_type: 'image/heic'
      )
      attachment.save!
      attachment
    end

    it 'downloads attachment to temporary file' do
      allow(attachment.file).to receive(:download).and_yield('chunk1').and_yield('chunk2')

      temp_file = service.send(:download_attachment, attachment)

      expect(temp_file).to be_a(Tempfile)
      temp_file.rewind
      content = temp_file.read
      expect(content).to eq('chunk1chunk2')

      temp_file.close
      temp_file.unlink
    end
  end

  describe '#convert_with_vips' do
    let(:input_file) { Tempfile.new(['test_input', '.heic']) }

    before do
      input_file.write('dummy heic content')
      input_file.rewind
    end

    after do
      input_file.close
      input_file.unlink
    end

    it 'raises error when vips produces empty file' do
      # ImageProcessing::Vips may not be available in CI (requires libvips)
      vips_module = begin
        ImageProcessing::Vips
      rescue LoadError
        skip 'libvips not available in this environment'
      end

      pipeline = double('vips_pipeline')
      allow(vips_module).to receive(:source).and_return(pipeline)
      allow(pipeline).to receive(:convert).and_return(pipeline)
      allow(pipeline).to receive(:saver).and_return(pipeline)
      allow(pipeline).to receive(:call)
      allow(File).to receive(:size?).and_return(nil)

      expect { service.send(:convert_with_vips, input_file) }
        .to raise_error('Vips conversion produced empty file')
    end
  end

  describe '#convert_with_ffmpeg' do
    let(:input_file) { Tempfile.new(['test_input', '.heic']) }

    before do
      input_file.write('dummy heic content')
      input_file.rewind
    end

    after do
      input_file.close
      input_file.unlink
    end

    context 'when FFmpeg succeeds' do
      before do
        allow(service).to receive(:system).and_return(true)
        allow(File).to receive(:size?).and_return(1024)
      end

      it 'converts file to JPEG format' do
        output_file = service.send(:convert_with_ffmpeg, input_file)

        expect(output_file).to be_a(Tempfile)
        expect(service).to have_received(:system).with(
          'ffmpeg', '-i', input_file.path,
          '-vframes', '1',
          '-q:v', '2',
          '-f', 'image2',
          '-y', output_file.path,
          out: File::NULL,
          err: File::NULL
        )

        output_file.close
        output_file.unlink
      end
    end

    context 'when FFmpeg fails' do
      before do
        allow(service).to receive(:system).and_return(false)
      end

      it 'raises error' do
        expect { service.send(:convert_with_ffmpeg, input_file) }
          .to raise_error(/FFmpeg HEIC conversion failed/)
      end
    end
  end

  describe '#convert_heic_to_jpeg' do
    let(:input_file) { Tempfile.new(['test_input', '.heic']) }

    before do
      input_file.write('dummy heic content')
      input_file.rewind
    end

    after do
      input_file.close
      input_file.unlink
    end

    it 'falls back to FFmpeg when Vips fails' do
      allow(service).to receive(:convert_with_vips).and_raise(StandardError.new('Vips not available'))
      ffmpeg_output = Tempfile.new(['ffmpeg_output', '.jpg'])
      allow(service).to receive(:convert_with_ffmpeg).and_return(ffmpeg_output)

      result = service.send(:convert_heic_to_jpeg, input_file)

      expect(result).to eq(ffmpeg_output)
      expect(service).to have_received(:convert_with_vips)
      expect(service).to have_received(:convert_with_ffmpeg)

      ffmpeg_output.close
      ffmpeg_output.unlink
    end
  end

  describe '#cleanup_temp_files' do
    let(:temp_file1) { double('temp_file1', close: nil, unlink: nil) }
    let(:temp_file2) { double('temp_file2', close: nil, unlink: nil) }
    let(:invalid_file) { 'not_a_file' }

    it 'cleans up valid temporary files' do
      allow(temp_file1).to receive(:respond_to?).with(:close).and_return(true)
      allow(temp_file1).to receive(:respond_to?).with(:unlink).and_return(true)
      allow(temp_file1).to receive(:closed?).and_return(false)
      allow(temp_file2).to receive(:respond_to?).with(:close).and_return(true)
      allow(temp_file2).to receive(:respond_to?).with(:unlink).and_return(true)
      allow(temp_file2).to receive(:closed?).and_return(false)

      service.send(:cleanup_temp_files, [temp_file1, temp_file2, nil])

      expect(temp_file1).to have_received(:close)
      expect(temp_file1).to have_received(:unlink)
      expect(temp_file2).to have_received(:close)
      expect(temp_file2).to have_received(:unlink)
    end

    it 'handles cleanup errors gracefully' do
      allow(temp_file1).to receive(:respond_to?).with(:close).and_return(true)
      allow(temp_file1).to receive(:closed?).and_return(false)
      allow(temp_file1).to receive(:close).and_raise(StandardError.new('Cleanup failed'))
      expect(Rails.logger).to receive(:warn).with(/WHAPI: Failed to cleanup temp file/)

      expect { service.send(:cleanup_temp_files, [temp_file1]) }.not_to raise_error
    end

    it 'skips invalid files' do
      expect { service.send(:cleanup_temp_files, [invalid_file]) }.not_to raise_error
    end
  end

  describe 'constants' do
    it 'defines HEIC content types' do
      expect(described_class::HEIC_CONTENT_TYPES).to contain_exactly(
        'image/heic', 'image/heif', 'image/heic-sequence', 'image/heif-sequence'
      )
    end

    it 'defines JPEG quality' do
      expect(described_class::JPEG_QUALITY).to eq(85)
    end
  end
end
