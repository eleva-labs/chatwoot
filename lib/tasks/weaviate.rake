namespace :weaviate do
  desc 'Create the KnowledgeBaseChunk collection in Weaviate'
  task setup: :environment do
    puts 'Creating Weaviate collection...'
    KnowledgeBase::WeaviateService.setup_collection!
    puts 'Done.'
  rescue Weaviate::Error => e
    if e.message.include?('already exists')
      puts 'Collection already exists — skipping.'
    else
      raise
    end
  end
end
