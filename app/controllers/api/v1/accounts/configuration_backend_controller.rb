# app/controllers/api/v1/accounts/configuration_backend_controller.rb
class Api::V1::Accounts::ConfigurationBackendController < Api::V1::Accounts::BaseController
  def create
    Rails.logger.debug '=== ConfigurationBackendController#create called ==='

    # Use account.id directly as the store external_id (matching the listener pattern)
    store_id = Current.account.id

    configuration_service = AiBackendService::ConfigurationService.new
    result = configuration_service.save_configuration(
      scope: AiBackendService::Constants::Scope::STORE,
      resource_id: store_id,
      config_key: permitted_params[:key],
      config_data: permitted_params[:data]
    )

    render json: result
  rescue AiBackendService::ConfigurationService::ConfigurationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def permitted_params
    params.require(:configuration).permit(:key, data: {})
  end
end
