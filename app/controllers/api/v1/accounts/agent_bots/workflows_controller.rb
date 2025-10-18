# frozen_string_literal: true

class Api::V1::Accounts::AgentBots::WorkflowsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_agent_bot

  def default
    service = AiBackendService::PromptsService.new(
      account_id: Current.account.id,
      bot_id: @agent_bot.id
    )

    workflow = service.default_prompt
    render json: workflow, status: :ok

  rescue AiBackendService::PromptsService::PromptsError => e
    Rails.logger.error("WorkflowsController - PromptsError: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("WorkflowsController - Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    render json: { error: I18n.t('errors.workflows.fetch_failed') }, status: :internal_server_error
  end

  private

  def set_agent_bot
    @agent_bot = Current.account.agent_bots.find(params[:bot_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('errors.agent_bots.not_found') }, status: :not_found
  end

  def check_authorization
    authorize(AgentBot)
  end
end
