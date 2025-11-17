class Integrations::OpenaiStreamService
  include ExternalApiCircuitBreaker

  API_URL = 'https://api.openai.com/v1/chat/completions'.freeze

  attr_reader :messages, :model

  def initialize(messages:, model: 'gpt-3.5-turbo')
    @messages = messages
    @model = model
  end

  def stream_chat(&)
    body = {
      model: model,
      messages: format_messages(messages),
      stream: true,
      temperature: 0.7,
      max_tokens: 1000
    }.to_json

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{api_key}",
      'Accept' => 'text/event-stream'
    }

    Rails.logger.info("OpenAI streaming request: #{body}")

    with_circuit_breaker('openai_api') do
      make_streaming_request(headers, body, &)
    end
  rescue StandardError => e
    Rails.logger.error("OpenAI streaming error: #{e.message}")
    yield 'Error: Unable to process request' if block_given?
  end

  private

  def make_streaming_request(headers, body)
    require 'net/http'
    require 'json'

    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    headers.each { |key, value| request[key] = value }
    request.body = body

    http.request(request) do |response|
      if response.code == '200'
        response.read_body do |chunk|
          process_stream_chunk(chunk) { |content| yield content if block_given? }
        end
      else
        Rails.logger.error("OpenAI API error: #{response.code} - #{response.body}")
        yield 'Error: API request failed' if block_given?
      end
    end
  end

  def process_stream_chunk(chunk)
    # Split chunk by lines and process each line
    chunk.split("\n").each do |line|
      line = line.strip
      next if line.empty?
      next unless line.start_with?('data: ')

      data = line[6..-1] # Remove 'data: ' prefix
      next if data == '[DONE]'

      begin
        json_data = JSON.parse(data)
        if json_data.dig('choices', 0, 'delta', 'content')
          content = json_data.dig('choices', 0, 'delta', 'content')
          yield content if block_given?
        end
      rescue JSON::ParserError => e
        Rails.logger.debug { "JSON parse error: #{e.message}" }
        # Continue processing other chunks
      end
    end
  end

  def format_messages(messages)
    messages.map do |message|
      {
        role: message[:role] || message['role'],
        content: message[:content] || message['content']
      }
    end
  end

  def api_key
    ENV['OPENAI_API_KEY'] || raise('OpenAI API key not configured')
  end
end