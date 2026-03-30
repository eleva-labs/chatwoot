require 'weaviate'

class KnowledgeBase::WeaviateService
  COLLECTION_NAME = 'KnowledgeBaseChunk'.freeze

  class << self
    # Initialize the Weaviate Cloud client
    def client
      @client ||= Weaviate::Client.new(
        url: ENV.fetch('WEAVIATE_URL'),           # e.g., https://your-cluster-id.weaviate.cloud
        api_key: ENV.fetch('WEAVIATE_API_KEY'),    # Weaviate Cloud API key
        model_service: :openai,
        model_service_api_key: ENV.fetch('OPENAI_API_KEY')
      )
    end

    # Create the collection schema (run once during setup)
    # Uses direct Faraday call because weaviate-ruby gem doesn't pass
    # multi_tenant and module_config params correctly
    def setup_collection!
      connection = Faraday.new(url: ENV.fetch('WEAVIATE_URL')) do |f|
        f.request :json
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end

      connection.post('/v1/schema') do |req|
        req.headers['Authorization'] = "Bearer #{ENV.fetch('WEAVIATE_API_KEY')}"
        req.headers['X-OpenAI-Api-Key'] = ENV.fetch('OPENAI_API_KEY')
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          class: COLLECTION_NAME,
          description: 'Knowledge base text chunks for RAG',
          vectorizer: 'text2vec-openai',
          moduleConfig: {
            'text2vec-openai' => {},
            'generative-openai' => {}
          },
          multiTenancyConfig: { enabled: true },
          properties: [
            { name: 'content', dataType: ['text'], description: 'Chunk text content' },
            { name: 'knowledge_base_id', dataType: ['text'], description: 'FK to PostgreSQL knowledge_bases' },
            { name: 'chunk_index', dataType: ['int'], description: 'Position within source document' },
            { name: 'source_type', dataType: ['text'], description: 'webpage, file, or image' },
            { name: 'source_name', dataType: ['text'], description: 'Original filename or URL' }
          ]
        }
      end
    end

    # Ensure tenant exists for an account
    def ensure_tenant!(account_id)
      tenant_name = tenant_for(account_id)
      client.schema.add_tenants(
        class_name: COLLECTION_NAME,
        tenants: [tenant_name]
      )
    rescue StandardError => e
      # Tenant already exists — safe to ignore (Weaviate returns 422 via Faraday)
      raise unless e.message.include?('already exists') || e.message.include?('422')
    end

    # Insert chunks into Weaviate (auto-generates embeddings)
    def insert(knowledge_base:, chunks:)
      tenant_name = tenant_for(knowledge_base.account_id)
      ensure_tenant!(knowledge_base.account_id)

      objects = chunks.each_with_index.map do |chunk_text, index|
        {
          class: COLLECTION_NAME,
          tenant: tenant_name,
          properties: {
            content: chunk_text,
            knowledge_base_id: knowledge_base.id.to_s,
            chunk_index: index,
            source_type: knowledge_base.source_type,
            source_name: knowledge_base.name
          }
        }
      end

      # Batch insert (Weaviate auto-vectorizes each chunk via text2vec-openai)
      client.objects.batch_create(objects: objects)
    end

    # Delete all chunks for a specific knowledge base
    # Rescues broadly so Weaviate failures don't block KB deletion
    def delete_by_knowledge_base(knowledge_base:)
      tenant_name = tenant_for(knowledge_base.account_id)

      client.objects.batch_delete(
        class_name: COLLECTION_NAME,
        tenant: tenant_name,
        where: {
          path: ['knowledge_base_id'],
          operator: 'Equal',
          valueText: knowledge_base.id.to_s
        }
      )
    rescue StandardError => e
      Rails.logger.warn("Weaviate delete failed for KB #{knowledge_base.id}: #{e.message}")
    end

    # Delete entire tenant (all data for an account)
    # Rescues broadly so Weaviate failures don't block account deletion
    def delete_tenant!(account_id)
      client.schema.remove_tenants(
        class_name: COLLECTION_NAME,
        tenants: [tenant_for(account_id)]
      )
    rescue StandardError => e
      Rails.logger.warn("Weaviate tenant delete failed for account #{account_id}: #{e.message}")
    end

    private

    def tenant_for(account_id)
      "account_#{account_id}"
    end
  end
end
