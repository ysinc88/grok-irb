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

module GrokIRB
  GROK_API_KEY = ENV['GROK_API_KEY']
  GROK_API_URL = 'https://api.x.ai/v1/chat/completions'
  
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
      content = parsed.dig('choices', 0, 'message', 'content').to_s

      # Extract and clean code
      code = if content.include?('```')
        content.split('```').find { |block| block.strip.start_with?('ruby') }&.strip&.sub(/^ruby\n/, '') ||
        content.split('```')[1]&.strip
      else
        content.strip
      end

      # Clean the code
      code&.lines&.map { |line| line.split('#=>').first.rstrip }&.join("\n")&.strip
    end

    def system_prompt
      context = if defined?(Rails)
        gems = begin
          Bundler.load.specs.map(&:name).sort.join(', ')
        rescue LoadError, StandardError => e
          "bundler not accessible"
        end
        
        "Rails v#{Rails::VERSION::STRING}. Gems: #{gems}"
      else
        "Standard Ruby environment"
      end

      "You are an AI assistant providing Ruby/Rails code suggestions. " \
      "Environment: #{context}. " \
      "Important: Respond ONLY with code. No explanations. No markdown. No code block markers. " \
      "No execution results or comments after #=>. Just the pure Ruby code."
    end
  end
end

# Define global grok method for easy access
def grok(prompt)
  GrokIRB.api_request(prompt)
end

puts "Grok integration loaded! Use grok 'your prompt' to get code suggestions."