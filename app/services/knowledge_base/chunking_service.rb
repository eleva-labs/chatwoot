class KnowledgeBase::ChunkingService
  DEFAULT_CHUNK_SIZE = 500     # tokens (approx 4 chars per token)
  DEFAULT_CHUNK_OVERLAP = 50   # tokens overlap between chunks
  CHARS_PER_TOKEN = 4          # rough approximation

  class << self
    def chunk(text, chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_CHUNK_OVERLAP)
      return [] if text.blank?

      max_chars = chunk_size * CHARS_PER_TOKEN
      overlap_chars = overlap * CHARS_PER_TOKEN

      chunks = []
      start_pos = 0

      while start_pos < text.length
        end_pos = start_pos + max_chars

        if end_pos < text.length
          # Find the last sentence boundary within the chunk
          boundary = find_sentence_boundary(text, start_pos, end_pos)
          end_pos = boundary if boundary > start_pos
        else
          end_pos = text.length
        end

        chunk_text = text[start_pos...end_pos].strip
        chunks << chunk_text unless chunk_text.empty?

        # Move forward by chunk size minus overlap
        new_start = end_pos - overlap_chars
        # Ensure forward progress to avoid infinite loop; skip overlap for last chunk
        start_pos = if new_start <= start_pos || end_pos >= text.length
                      end_pos
                    else
                      new_start
                    end
      end

      chunks
    end

    private

    def find_sentence_boundary(text, start_pos, end_pos)
      # Look backwards from end_pos for a sentence-ending punctuation
      search_region = text[start_pos...end_pos]

      # Try to find the last sentence boundary (., !, ?, or newline)
      last_boundary = search_region.rindex(/[.!?\n]\s/)
      return start_pos + last_boundary + 1 if last_boundary

      # Fallback: find the last space
      last_space = search_region.rindex(' ')
      return start_pos + last_space + 1 if last_space

      # No boundary found — use the full chunk
      end_pos
    end
  end
end
