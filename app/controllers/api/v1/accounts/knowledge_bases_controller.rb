class Api::V1::Accounts::KnowledgeBasesController < Api::V1::Accounts::BaseController
  before_action :fetch_knowledge_base, only: [:show, :update, :destroy]

  def index
    @knowledge_bases = Current.account.knowledge_bases
    render json: @knowledge_bases.map { |kb| knowledge_base_response(kb) }
  end

  def show
    render json: knowledge_base_response(@knowledge_base)
  end

  def create
    @knowledge_base = Current.account.knowledge_bases.new(knowledge_base_params)

    if @knowledge_base.save
      # Enqueue with small delay to ensure blob upload transaction is committed
      KnowledgeBaseProcessingJob.set(wait: 3.seconds).perform_later(@knowledge_base.id)
      render json: knowledge_base_response(@knowledge_base), status: :created
    else
      render json: @knowledge_base.errors, status: :unprocessable_entity
    end
  end

  def update
    if @knowledge_base.update(knowledge_base_params)
      render json: knowledge_base_response(@knowledge_base)
    else
      render json: @knowledge_base.errors, status: :unprocessable_entity
    end
  end

  def destroy
    # Clean up Weaviate Cloud chunks before deleting the record
    KnowledgeBase::WeaviateService.delete_by_knowledge_base(knowledge_base: @knowledge_base)
    @knowledge_base.destroy!
    head :ok
  end

  # NOTE: No search endpoint here. Querying Weaviate for RAG happens
  # in the ChatsCommerce Python backend during conversations.

  private

  def fetch_knowledge_base
    @knowledge_base = Current.account.knowledge_bases.find_by(id: params[:id])
    head :not_found unless @knowledge_base
  end

  def knowledge_base_params
    params.require(:knowledge_base).permit(:name, :source_type, :url)
  end

  def knowledge_base_response(kb)
    # as_json returns status as integer (0,1,2,3). Override with the string
    # name so the frontend can compare against 'pending', 'processing', etc.
    kb.as_json.merge(status: kb.status)
  end
end
