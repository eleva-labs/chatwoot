# frozen_string_literal: true

# Controller for purchasing conversation packs
class Api::V2::Accounts::Billing::ConversationPacksController < Api::BaseController
  include SwitchLocale
  include EnsureCurrentAccountHelper

  before_action :current_account
  before_action :check_authorization

  # GET /api/v2/accounts/:account_id/billing/conversation_packs
  # Returns conversation pack availability and pricing
  def show
    limit_service = Billing::ConversationLimitService.new(current_account)
    pack_info = limit_service.conversation_pack_info
    status = limit_service.status

    render json: {
      success: true,
      data: {
        account_id: current_account.id,
        plan_name: current_account.custom_attributes&.dig('plan_name'),
        pack_available: pack_info.present?,
        pack_info: pack_info,
        current_status: status
      }
    }
  rescue StandardError => e
    Rails.logger.error "Error fetching conversation pack info: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to fetch conversation pack information'
    }, status: :internal_server_error
  end

  # POST /api/v2/accounts/:account_id/billing/conversation_packs/purchase
  # Purchases a one-time conversation pack
  def purchase
    service = Billing::PurchaseConversationPackService.new(current_account)
    result = service.perform

    if result[:success]
      render json: {
        success: true,
        message: result[:message],
        data: {
          conversations_added: result[:conversations_added],
          new_total: result[:new_total],
          invoice_id: result[:invoice_id],
          amount: result[:amount],
          currency: result[:currency]
        }
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Error purchasing conversation pack: #{e.message}"
    render json: {
      success: false,
      error: 'Failed to purchase conversation pack'
    }, status: :internal_server_error
  end

  private

  def check_authorization
    authorize(:account, :billing_access?)
  rescue Pundit::NotAuthorizedError
    render json: { error: 'Access denied' }, status: :forbidden
  end
end

