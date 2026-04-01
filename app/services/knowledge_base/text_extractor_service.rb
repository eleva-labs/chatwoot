require 'net/http'

class KnowledgeBase::TextExtractorService
  class ExtractionError < StandardError; end

  class << self
    def extract(knowledge_base)
      case knowledge_base.source_type
      when 'webpage'
        extract_from_webpage(knowledge_base.url)
      when 'file'
        extract_from_file(knowledge_base)
      when 'image'
        extract_from_image(knowledge_base)
      else
        raise ExtractionError, "Unknown source type: #{knowledge_base.source_type}"
      end
    end

    private

    def extract_from_webpage(url)
      uri = URI(url)
      response = Net::HTTP.get(uri)
      doc = Nokogiri::HTML(response)

      # Remove scripts, styles, nav, footer
      doc.css('script, style, nav, footer, header, aside').remove

      # Extract text from body
      text = doc.css('body').text
      clean_text(text)
    rescue StandardError => e
      raise ExtractionError, "Failed to extract from webpage #{url}: #{e.message}"
    end

    def extract_from_file(knowledge_base)
      # ActiveStorage's has_many_attached doesn't work with UUID primary keys
      # (record_id is bigint). Look up the blob directly from the URL instead.
      url = knowledge_base.url
      raise ExtractionError, 'No file URL available' if url.blank?

      # Extract blob signed_id from the ActiveStorage redirect URL and find the blob
      blob = find_blob_from_url(url)
      raise ExtractionError, 'Could not find file blob' unless blob

      content_type = blob.content_type || detect_content_type(knowledge_base.name)

      # Download blob content directly (no HTTP request needed)
      tempfile = Tempfile.new(['kb_extract', extension_for(content_type)])
      tempfile.binmode
      blob.download { |chunk| tempfile.write(chunk) }
      tempfile.rewind

      text = case content_type
             when 'application/pdf'
               extract_pdf(tempfile.path)
             when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
               extract_docx(tempfile.path)
             when 'text/plain', 'text/csv'
               File.read(tempfile.path)
             else
               raise ExtractionError, "Unsupported file type: #{content_type}"
             end

      clean_text(text)
    ensure
      tempfile&.close
      tempfile&.unlink
    end

    def extract_from_image(knowledge_base)
      # For images, we generate a text description via OpenAI Vision API
      url = knowledge_base.url
      raise ExtractionError, 'No image URL available' if url.blank?

      client = OpenAI::Client.new(access_token: ENV.fetch('OPENAI_API_KEY'))
      response = client.chat(
        parameters: {
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'user',
              content: [
                { type: 'text', text: 'Describe this image in detail. Include all visible text, labels, and relevant information.' },
                { type: 'image_url', image_url: { url: url } }
              ]
            }
          ]
        }
      )

      response.dig('choices', 0, 'message', 'content') || ''
    rescue StandardError => e
      raise ExtractionError, "Failed to extract from image: #{e.message}"
    end

    def extract_pdf(path)
      reader = PDF::Reader.new(path)
      reader.pages.map(&:text).join("\n\n")
    end

    def extract_docx(path)
      doc = Docx::Document.open(path)
      doc.paragraphs.map(&:text).join("\n\n")
    end

    def find_blob_from_url(url)
      # Extract the signed_id from ActiveStorage redirect URLs like:
      # /rails/active_storage/blobs/redirect/SIGNED_ID/filename
      match = url.match(%r{/blobs/redirect/([^/]+)/})
      return nil unless match

      signed_id = match[1]
      ActiveStorage::Blob.find_signed(signed_id)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      # If signed_id is invalid, try finding by filename
      filename = url.split('/').last
      ActiveStorage::Blob.find_by(filename: filename)
    end

    def detect_content_type(filename)
      ext = File.extname(filename).downcase
      {
        '.pdf' => 'application/pdf',
        '.docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.doc' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.txt' => 'text/plain',
        '.csv' => 'text/csv'
      }.fetch(ext, 'application/octet-stream')
    end

    def extension_for(content_type)
      {
        'application/pdf' => '.pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => '.docx',
        'text/plain' => '.txt',
        'text/csv' => '.csv'
      }.fetch(content_type, '.tmp')
    end

    def clean_text(text)
      text
        .gsub(/\n{3,}/, "\n\n")     # collapse excessive newlines first
        .gsub(/[^\S\n]+/, ' ')      # collapse horizontal whitespace (spaces, tabs) but preserve newlines
        .strip
    end
  end
end
