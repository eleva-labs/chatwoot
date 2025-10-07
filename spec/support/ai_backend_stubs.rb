# frozen_string_literal: true

module AiBackendStubs
  # Stub all AI Backend API calls to prevent real HTTP requests during tests
  # This is called automatically before each test via RSpec configuration
  def stub_ai_backend_requests
    ai_backend_url = Rails.application.config.ai_backend_api_url || 'http://localhost:8000'

    # Store creation (triggered by account creation)
    stub_request(:post, "#{ai_backend_url}/api/stores")
      .to_return(status: 200, body: { id: 'store-uuid', external_id: '123' }.to_json, headers: { 'Content-Type' => 'application/json' })

    # User creation (triggered by user account association)
    stub_request(:post, "#{ai_backend_url}/api/users")
      .to_return(status: 200, body: { id: 'user-uuid', external_id: '456' }.to_json, headers: { 'Content-Type' => 'application/json' })

    # Agent system creation (triggered by agent bot creation)
    stub_request(:post, "#{ai_backend_url}/api/agent_systems")
      .to_return(status: 200, body: { id: 'agent-system-uuid', external_id: '789' }.to_json, headers: { 'Content-Type' => 'application/json' })

    # Configuration retrieval (used by services)
    stub_request(:get, %r{#{Regexp.escape(ai_backend_url)}/api/configurations})
      .to_return(status: 200, body: { configuration: { data: {} } }.to_json, headers: { 'Content-Type' => 'application/json' })

    # Store deletion (triggered by account deletion)
    stub_request(:delete, %r{#{Regexp.escape(ai_backend_url)}/api/stores/.*})
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

    # User deletion (triggered by user removal)
    stub_request(:delete, %r{#{Regexp.escape(ai_backend_url)}/api/users/.*})
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

    # Agent system deletion (triggered by agent bot deletion)
    stub_request(:delete, %r{#{Regexp.escape(ai_backend_url)}/api/agent_systems/.*})
      .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
  end
end
