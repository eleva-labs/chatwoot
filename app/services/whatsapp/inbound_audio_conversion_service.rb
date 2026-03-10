# app/services/whatsapp/inbound_audio_conversion_service.rb

# Converts inbound WhatsApp voice messages from OGG Opus to M4A (AAC)
# so they can be played on iOS devices which don't support OGG natively.
#
# Pattern: Mirrors Instagram::AudioConversionService and Whatsapp::AudioConversionService
# for consistency (temp file management, error handling, cleanup).
class Whatsapp::InboundAudioConversionService
  # OGG/Opus content types that need conversion for iOS playback
  OGG_CONTENT_TYPES = %w[audio/ogg audio/opus audio/ogg;codecs=opus].freeze

  # Maximum time (seconds) to allow FFmpeg conversion before killing the process.
  # 60s is generous -- a 15-minute voice message converts in ~3-5 seconds.
  FFMPEG_TIMEOUT = 60

  # Converts a downloaded voice file (Tempfile from Down.download) from OGG to M4A.
  # Returns a Hash { io:, filename:, content_type: } ready for ActiveStorage,
  # or the original file attributes if conversion is not needed or fails.
  #
  # @param downloaded_file [Tempfile] The downloaded attachment file (from Down.download)
  # @param message_type [String] The WHAPI message type ('voice', 'audio', etc.)
  # @return [Hash] { io:, filename:, content_type: } ready for ActiveStorage
  def self.convert_if_voice(downloaded_file, message_type)
    new.convert_if_voice(downloaded_file, message_type)
  end

  def convert_if_voice(downloaded_file, message_type)
    original_attrs = {
      io: downloaded_file,
      filename: downloaded_file.original_filename,
      content_type: downloaded_file.content_type
    }

    return original_attrs unless should_convert?(downloaded_file, message_type)

    Rails.logger.info '[WHAPI_INBOUND_AUDIO] Converting OGG voice message to M4A ' \
                      "(content_type: #{downloaded_file.content_type}, filename: #{downloaded_file.original_filename})"

    begin
      m4a_file = convert_ogg_to_m4a(downloaded_file)

      converted_filename = replace_extension(downloaded_file.original_filename, '.m4a')

      Rails.logger.info "[WHAPI_INBOUND_AUDIO] Conversion successful: #{File.size(m4a_file.path)} bytes, filename: #{converted_filename}"

      {
        io: m4a_file,
        filename: converted_filename,
        content_type: 'audio/mp4'
      }
    rescue StandardError => e
      Rails.logger.error "[WHAPI_INBOUND_AUDIO] Conversion failed: #{e.message}. Using original OGG file."
      original_attrs
    end
  end

  private

  def should_convert?(downloaded_file, message_type)
    return false unless %w[voice audio].include?(message_type.to_s)

    content_type = normalize_content_type(downloaded_file.content_type)
    OGG_CONTENT_TYPES.include?(content_type)
  end

  def normalize_content_type(content_type)
    return '' if content_type.blank?

    # Normalize whitespace around semicolons and downcase:
    # "audio/ogg; codecs=opus" -> "audio/ogg;codecs=opus"
    # "Audio/OGG" -> "audio/ogg"
    content_type.to_s.downcase.gsub(/\s*;\s*/, ';')
  end

  def convert_ogg_to_m4a(input_file)
    verify_ffmpeg_availability

    input_temp = nil
    output_temp = nil
    stderr_output = nil

    begin
      # Down.download returns a Tempfile -- copy its contents for FFmpeg input
      # (the original Tempfile may have an unrecognized extension)
      input_temp = Tempfile.new(['whapi_inbound_ogg_', '.ogg'])
      input_temp.binmode
      input_file.rewind if input_file.respond_to?(:rewind)
      IO.copy_stream(input_file, input_temp)
      input_temp.flush

      output_temp = Tempfile.new(['whapi_inbound_m4a_', '.m4a'])

      # FFmpeg command: OGG Opus -> M4A (AAC) for universal playback
      # Settings optimized for voice (mono, 64k bitrate, 48kHz to match Opus source):
      #   -c:a aac       -- Built-in AAC encoder (available in Alpine ffmpeg, no libfdk_aac needed)
      #   -b:a 64k       -- 64 kbit/s mono is excellent for speech (matches outbound AudioConversionService)
      #   -ar 48000      -- Match WhatsApp Opus source rate (avoids unnecessary resampling)
      #   -ac 1          -- Mono (WhatsApp voice messages are always mono)
      #   -movflags +faststart -- Move moov atom to start for progressive/streaming playback
      #   -vn            -- Strip any video/album art streams
      command = [
        'ffmpeg', '-i', input_temp.path,
        '-c:a', 'aac',
        '-b:a', '64k',
        '-ar', '48000',
        '-ac', '1',
        '-movflags', '+faststart',
        '-f', 'mp4',
        '-vn',
        '-y', output_temp.path
      ]

      stderr_output = Tempfile.new('ffmpeg_stderr')
      success = nil

      Timeout.timeout(FFMPEG_TIMEOUT) do
        success = system(*command, out: File::NULL, err: stderr_output.path)
      end

      unless success && File.size?(output_temp.path)
        exit_status = $?.exitstatus
        stderr_content = begin
          File.read(stderr_output.path).truncate(500)
        rescue StandardError
          ''
        end
        raise "FFmpeg OGG->M4A conversion failed (exit: #{exit_status}): #{stderr_content}"
      end

      # Output temp file is returned as IO for ActiveStorage.
      # It must remain open until @message.save! reads it.
      # Ruby's Tempfile finalizer will clean it up after GC.
      output_temp.rewind
      output_temp
    rescue StandardError
      # Clean up output temp on failure (it won't be used)
      cleanup_temp_file(output_temp)
      raise
    ensure
      # Always clean up input temp and stderr temp -- they are never needed after this method
      cleanup_temp_file(input_temp)
      cleanup_temp_file(stderr_output)
    end
  end

  def replace_extension(filename, new_ext)
    return "voice_message#{new_ext}" if filename.blank?

    base = File.basename(filename, File.extname(filename))
    "#{base}#{new_ext}"
  end

  def verify_ffmpeg_availability
    return if system('which ffmpeg > /dev/null 2>&1')

    raise 'FFmpeg is not installed. Required for inbound voice message conversion.'
  end

  def cleanup_temp_file(file)
    return unless file.respond_to?(:close)

    file.close unless file.closed?
    file.unlink if file.respond_to?(:unlink)
  rescue StandardError => e
    Rails.logger.warn "[WHAPI_INBOUND_AUDIO] Failed to cleanup temp file: #{e.message}"
  end
end
