# app/services/whatsapp/image_conversion_service.rb

# Handles HEIC/HEIF image conversion to JPEG for WhatsApp (WHAPI) compatibility.
# WHAPI rejects image/heic with 415 Unsupported Media Type.
#
# Uses ImageProcessing::Vips (requires vips-heif Alpine package) as the primary
# conversion method, with FFmpeg as a fallback. Vips handles EXIF auto-rotation,
# ICC profile conversion, and alpha-channel flattening correctly.
class Whatsapp::ImageConversionService
  HEIC_CONTENT_TYPES = %w[image/heic image/heif image/heic-sequence image/heif-sequence].freeze
  JPEG_QUALITY = 85

  # Converts HEIC attachment to JPEG if needed.
  # Returns [file_content_bytes, content_type_string]
  def self.convert_if_needed(attachment)
    new.convert_if_needed(attachment)
  end

  def convert_if_needed(attachment)
    return [attachment.file.download, attachment.file.content_type] unless should_convert?(attachment)

    Rails.logger.info "WHAPI: Converting HEIC attachment##{attachment.id} to JPEG for WhatsApp compatibility"

    begin
      original_file = download_attachment(attachment)
      jpeg_file = convert_heic_to_jpeg(original_file)
      jpeg_content = File.binread(jpeg_file.path)

      Rails.logger.info "WHAPI: HEIC->JPEG conversion successful for attachment##{attachment.id} " \
                        "(#{jpeg_content.size} bytes)"

      [jpeg_content, 'image/jpeg']
    rescue StandardError => e
      Rails.logger.error "WHAPI: HEIC conversion failed for attachment##{attachment.id}: #{e.message}. " \
                         'Using original file as fallback.'
      [attachment.file.download, attachment.file.content_type]
    ensure
      cleanup_temp_files([original_file, jpeg_file])
    end
  end

  private

  def should_convert?(attachment)
    return false unless attachment.file_type == 'image' && attachment.file.attached?

    HEIC_CONTENT_TYPES.include?(attachment.file.content_type&.downcase)
  end

  def download_attachment(attachment)
    temp_file = Tempfile.new(['whapi_heic_', '.heic'])
    temp_file.binmode
    attachment.file.download { |chunk| temp_file.write(chunk) }
    temp_file.rewind
    temp_file
  end

  def convert_heic_to_jpeg(input_file)
    convert_with_vips(input_file)
  rescue StandardError => e
    Rails.logger.warn "WHAPI: Vips HEIC conversion failed (#{e.message}), trying FFmpeg fallback"
    convert_with_ffmpeg(input_file)
  end

  # Primary: ImageProcessing::Vips -- handles EXIF rotation, ICC profiles, alpha flattening
  def convert_with_vips(input_file)
    output_file = Tempfile.new(['whapi_converted_', '.jpg'])

    ImageProcessing::Vips
      .source(input_file.path)
      .convert('jpeg')
      .saver(quality: JPEG_QUALITY, strip: false) # strip: false preserves EXIF (vips auto-rotates)
      .call(destination: output_file.path)

    raise 'Vips conversion produced empty file' unless File.size?(output_file.path)

    output_file
  rescue StandardError
    cleanup_temp_files([output_file])
    raise
  end

  # Fallback: FFmpeg -- works if vips-heif is not installed but ffmpeg has HEVC decoder
  def convert_with_ffmpeg(input_file)
    output_file = Tempfile.new(['whapi_converted_', '.jpg'])

    command = [
      'ffmpeg', '-i', input_file.path,
      '-vframes', '1',        # Single frame (HEIC is a single image)
      '-q:v', '2',            # High quality JPEG (2 = very good, scale 1-31)
      '-f', 'image2',         # Image output format
      '-y', output_file.path  # Overwrite output
    ]

    success = system(*command, out: File::NULL, err: File::NULL)
    raise "FFmpeg HEIC conversion failed (exit status: #{$?.exitstatus})" unless success && File.size?(output_file.path)

    output_file
  rescue StandardError
    cleanup_temp_files([output_file])
    raise
  end

  def cleanup_temp_files(files)
    files.compact.each do |file|
      next unless file.respond_to?(:close)

      file.close unless file.closed?
      file.unlink if file.respond_to?(:unlink)
    rescue StandardError => e
      Rails.logger.warn "WHAPI: Failed to cleanup temp file: #{e.message}"
    end
  end
end
