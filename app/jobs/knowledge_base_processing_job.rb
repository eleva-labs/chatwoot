class KnowledgeBaseProcessingJob < ApplicationJob
  queue_as :low
  discard_on ActiveRecord::RecordNotFound
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(knowledge_base_id)
    @knowledge_base = KnowledgeBase.find(knowledge_base_id)
    @knowledge_base.update!(status: 'processing', error_message: nil)

    # Clean up any chunks from a previous failed attempt to avoid duplicates on retry
    KnowledgeBase::WeaviateService.delete_by_knowledge_base(knowledge_base: @knowledge_base)

    # 1. Extract text from file/URL
    content = KnowledgeBase::TextExtractorService.extract(@knowledge_base)

    if content.blank?
      @knowledge_base.update!(status: 'failed', error_message: 'No text content could be extracted')
      return
    end

    # 2. Chunk the content
    chunks = KnowledgeBase::ChunkingService.chunk(content)

    if chunks.empty?
      @knowledge_base.update!(status: 'failed', error_message: 'Content could not be chunked')
      return
    end

    # 3. Insert chunks into Weaviate (auto-generates embeddings via text2vec-openai)
    KnowledgeBase::WeaviateService.insert(
      knowledge_base: @knowledge_base,
      chunks: chunks
    )

    # 4. Update status in PostgreSQL
    @knowledge_base.update!(
      status: 'processed',
      chunk_count: chunks.size,
      processed_at: Time.current
    )

    # 5. Notify frontend via ActionCable
    broadcast_processing_complete
  rescue StandardError => e
    @knowledge_base&.update(status: 'failed', error_message: e.message)
    raise # Re-raise so Sidekiq retries
  end

  private

  def broadcast_processing_complete
    members = @knowledge_base.account.administrators.pluck(:id)
    ActionCableBroadcastJob.perform_later(
      members,
      'knowledge_base.processed',
      @knowledge_base.as_json.merge(status: @knowledge_base.status)
    )
  end
end
