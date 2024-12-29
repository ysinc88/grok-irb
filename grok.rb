# grok.rb
# Enhances IRB with AI-powered code suggestions via Grok API
# Usage: 
#   1. Add GROK_API_KEY to your environment variables
#   2. Include this file in your .irbrc
#   3. Use: grok "your prompt"

require 'readline'
require 'httpx'
require 'json'
require 'rails/version' if defined?(Rails)
require 'debug'

module GrokIRB
  GROK_API_KEY ||= ENV['GROK_API_KEY']
  GROK_API_URL ||= 'https://api.x.ai/v1/chat/completions'
  
  class Error < StandardError; end
  
  class << self
    def api_request(prompt)
      raise Error, "GROK_API_KEY not found in environment" unless GROK_API_KEY
      httpx = HTTPX.with(headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{GROK_API_KEY}"
      })
      response = httpx.post(
        GROK_API_URL,
        json: {
          model: 'grok-2-latest',
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: prompt }
          ]
        },
        timeout: { operation_timeout: 30 }
      )
      handle_response(response)
    rescue HTTPX::Error => e
      puts "Network error: #{e.message}"
      nil
    rescue JSON::ParserError => e
      puts "Invalid JSON response: #{e.message}"
      nil
    rescue => e
      puts "Error: #{e.message}"
      nil
    end

    private

    def handle_response(response)
      unless response.status == 200
        puts "API error (#{response.status}): #{response.body}"
        return nil
      end

      parsed = JSON.parse(response.body)
      parsed.dig('choices', 0, 'message', 'content')
    end

    def system_prompt
      context = if defined?(Rails)
        "Rails v#{Rails::VERSION::STRING}. " \
        "Gems: #{Bundler.load.specs.map(&:name).join(', ')}. "
      else
        "Standard Ruby environment"
      end

      "You are an AI assistant providing Ruby/Rails code suggestions. " \
      "Environment: #{context}. " \
      "Provide concise, practical code examples that can be directly used in IRB."
    end
  end
end

# Define global grok method for easy access
def grok(prompt)
  result = GrokIRB.api_request(prompt)
  if result
    puts "\n=== Grok Suggestion ===\n\n#{result}\n\n"
  end
  nil # Prevent result from showing in IRB
end

puts "Grok integration loaded! Use grok 'your prompt' to get suggestions."