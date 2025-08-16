class AiService
  include HTTParty
  
  def self.generate_customer_email(prompt)
    new.generate_customer_email(prompt)
  end
  
  def initialize
    @api_key = ENV['GROK_API_KEY']
    @api_url = ENV['GROK_API_URL'] || 'https://api.x.ai/v1/chat/completions'
  end
  
  def generate_customer_email(prompt)
    return mock_response(prompt) unless @api_key.present?
    
    response = HTTParty.post(@api_url, {
      headers: {
        'Authorization' => "Bearer #{@api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'grok-beta',
        messages: [
          {
            role: 'system',
            content: 'You are an expert in writing professional, educational customer update emails for service businesses. Focus on being informative, seasonal, and helpful.'
          },
          {
            role: 'user', 
            content: prompt
          }
        ],
        max_tokens: 500,
        temperature: 0.7
      }.to_json
    })
    
    if response.success?
      email_content = response.parsed_response.dig('choices', 0, 'message', 'content')
      {
        success: true,
        email_content: email_content,
        usage: response.parsed_response['usage']
      }
    else
      {
        success: false,
        error: "AI API Error: #{response.code} - #{response.body}"
      }
    end
  rescue => e
    {
      success: false,
      error: "AI Service Error: #{e.message}"
    }
  end
  
  private
  
  def mock_response(prompt)
    # Mock response for testing without API key
    {
      success: true,
      email_content: generate_mock_email,
      usage: { prompt_tokens: 150, completion_tokens: 200, total_tokens: 350 },
      mock: true
    }
  end
  
  def generate_mock_email
    <<~EMAIL
      Hello from your beekeeping team!

      We completed your hive inspection today and have great news to share. Your colonies are thriving this harvest season! The queens are actively laying, and we've added honey supers to your strongest hives to accommodate the excellent nectar flow.

      Current hive status:
      • All queens present and actively laying
      • Strong brood patterns observed
      • Honey supers added to prepare for harvest
      • Mite levels remain low - no treatment needed at this time

      This is the perfect time of year for honey production in Texas. The late summer blooms are providing excellent nectar sources, and your bees are taking full advantage. We'll continue monitoring mite levels as we head into fall.

      Your hives are in excellent condition for the harvest season ahead!

      [This is a mock email - replace with actual AI when API key is configured]
    EMAIL
  end
end
