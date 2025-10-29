class Api::V1::Accounts::AgentsController < Api::V1::Accounts::BaseController
  before_action :fetch_agent, except: [:create, :index, :bulk_create]
  before_action :check_authorization
  before_action :validate_limit, only: [:create]
  before_action :validate_limit_for_bulk_create, only: [:bulk_create]

  def index
    @agents = agents
  end

  def create
    builder = AgentBuilder.new(
      email: new_agent_params['email'],
      name: new_agent_params['name'],
      role: new_agent_params['role'],
      availability: new_agent_params['availability'],
      auto_offline: new_agent_params['auto_offline'],
      inviter: current_user,
      account: Current.account
    )

    @agent = builder.perform
  rescue ActiveRecord::RecordInvalid => e
    # Check if it's a limit error
    if e.record.errors[:base].any? { |error| error.include?('limit reached') }
      render_limit_error(:agent)
    else
      raise
    end
  end

  def update
    @agent.update!(agent_params.slice(:name).compact)
    @agent.current_account_user.update!(agent_params.slice(*account_user_attributes).compact)
  end

  def destroy
    @agent.current_account_user.destroy!
    delete_user_record(@agent)
    head :ok
  end

  def bulk_create
    emails = params[:emails]

    emails.each do |email|
      builder = AgentBuilder.new(
        email: email,
        name: email.split('@').first,
        inviter: current_user,
        account: Current.account
      )
      begin
        builder.perform
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.info "[Agent#bulk_create] ignoring email #{email}, errors: #{e.record.errors}"
      end
    end

    # This endpoint is used to bulk create agents during onboarding
    # onboarding_step key in present in Current account custom attributes, since this is a one time operation
    Current.account.custom_attributes.delete('onboarding_step')
    Current.account.save!
    head :ok
  end

  private

  def check_authorization
    super(User)
  end

  def fetch_agent
    @agent = agents.find(params[:id])
  end

  def account_user_attributes
    [:role, :availability, :auto_offline]
  end

  def allowed_agent_params
    [:name, :email, :role, :availability, :auto_offline]
  end

  def agent_params
    params.require(:agent).permit(allowed_agent_params)
  end

  def new_agent_params
    params.require(:agent).permit(:email, :name, :role, :availability, :auto_offline)
  end

  def agents
    @agents ||= Current.account.users.order_by_full_name.includes(:account_users, { avatar_attachment: [:blob] })
  end

  def validate_limit_for_bulk_create
    limit_service = Billing::UnifiedLimitService.new(Current.account, :agent)
    emails_count = params[:emails].count
    
    limit_available = limit_service.remaining >= emails_count

    render_limit_error(:agent, count: emails_count) unless limit_available
  end

  def validate_limit
    limit_service = Billing::UnifiedLimitService.new(Current.account, :agent)
    render_limit_error(:agent) unless limit_service.can_create?
  end

  def available_agent_count
    limit_service = Billing::UnifiedLimitService.new(Current.account, :agent)
    limit_service.remaining
  end

  def can_add_agent?
    available_agent_count.positive?
  end

  def render_limit_error(resource_type, options = {})
    limit_service = Billing::UnifiedLimitService.new(Current.account, resource_type)
    status_info = limit_service.status
    upgrade_options = limit_service.upgrade_options

    render json: {
      error: "#{resource_type.to_s.capitalize} limit reached",
      limit_info: {
        current: status_info[:current],
        base_limit: status_info[:base_limit],
        purchased: status_info[:purchased],
        total_allowed: status_info[:total_allowed],
        remaining: status_info[:remaining]
      },
      upgrade_options: upgrade_options
    }, status: :payment_required # HTTP 402
  end

  def delete_user_record(agent)
    DeleteObjectJob.perform_later(agent) if agent.reload.account_users.blank?
  end
end

Api::V1::Accounts::AgentsController.prepend_mod_with('Api::V1::Accounts::AgentsController')
