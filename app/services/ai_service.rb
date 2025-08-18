class AiService
  include HTTParty
  
  def self.generate_customer_email(prompt)
    new.generate_customer_email(prompt)
  end
  
  # NEW: Business-specific email generation
  def self.generate_business_email(service_notes:, business_profile:, customer_data:, location_data:, job_data:)
    new.generate_business_email(
      service_notes: service_notes,
      business_profile: business_profile, 
      customer_data: customer_data,
      location_data: location_data,
      job_data: job_data
    )
  end
  
  def initialize
    @api_key = ENV['GROK_API_KEY']
    @api_url = ENV['GROK_API_URL'] || 'https://api.x.ai/v1/chat/completions'
    @model = ENV['GROK_MODEL'] || 'grok-beta'
  end
  
  def generate_customer_email(prompt)
    # Existing method for backwards compatibility
    call_grok_api(build_generic_system_prompt, prompt)
  end
  
  def generate_business_email(service_notes:, business_profile:, customer_data:, location_data:, job_data:)
    # Build comprehensive prompt from all data sources
    system_prompt = build_business_system_prompt(business_profile)
    user_prompt = build_comprehensive_user_prompt(
      service_notes: service_notes,
      customer_data: customer_data, 
      location_data: location_data,
      job_data: job_data,
      business_profile: business_profile
    )
    
    Rails.logger.info "🏢 Generating email for #{business_profile[:business_name]}"
    Rails.logger.info "📍 Location: #{location_data[:city]}, #{location_data[:state]}"
    Rails.logger.info "📝 Service notes: #{service_notes[0..100]}..."
    
    call_grok_api(system_prompt, user_prompt)
  end
  
  private
  
  def call_grok_api(system_prompt, user_prompt)
    unless @api_key.present?
      Rails.logger.warn "🔧 GROK_API_KEY not found - using mock response"
      return mock_response(user_prompt)
    end
    
    Rails.logger.info "🤖 Calling Grok AI with model: #{@model}"
    
    response = HTTParty.post(@api_url, {
      headers: {
        'Authorization' => "Bearer #{@api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        model: @model,
        messages: [
          {
            role: 'system',
            content: system_prompt
          },
          {
            role: 'user', 
            content: user_prompt
          }
        ],
        max_tokens: 800,
        temperature: 0.7,
        top_p: 0.9
      }.to_json,
      timeout: 30
    })
    
    if response.success?

      # DEBUG:
      Rails.logger.info "🔍 Raw Grok Response:"
      Rails.logger.info "   Status: #{response.code}"
      Rails.logger.info "   Body: #{response.body[0..500]}..."
      Rails.logger.info "   Parsed: #{response.parsed_response.inspect[0..500]}..."

      email_content = response.parsed_response.dig('choices', 0, 'message', 'content')
      usage_data = response.parsed_response['usage']
      
      Rails.logger.info "✅ Grok AI Success!"
      Rails.logger.info "📊 Tokens used: #{usage_data['total_tokens']}" if usage_data
      
      {
        success: true,
        email_content: email_content,
        usage: usage_data,
        provider: 'grok',
        model: @model
      }
    else
      error_msg = "Grok API Error: #{response.code} - #{response.body}"
      Rails.logger.error "❌ #{error_msg}"
      
      {
        success: false,
        error: error_msg
      }
    end
  rescue => e
    error_msg = "Grok Service Error: #{e.message}"
    Rails.logger.error "💥 #{error_msg}"
    
    {
      success: false,
      error: error_msg
    }
  end
  
  def build_business_system_prompt(business_profile)
    <<~SYSTEM
      You are writing customer update emails for #{business_profile[:business_name]}, 
      a #{business_profile[:industry]} service company.
      
      Business Communication Style & Voice:
      #{business_profile[:communication_style]}
      
      Business Details:
      - Industry: #{business_profile[:industry]}
      - Services offered: #{business_profile[:services_offered]}
      - Unique approach: #{business_profile[:unique_approach]}
      - Contact information: #{business_profile[:contact_info]}
      - Business values: #{business_profile[:business_values]}
      
      Email Requirements:
      - Write complete customer update emails including greeting and signature
      - Use the specific business communication style provided
      - Include relevant business branding and contact information
      - Reference specific service details from the notes provided
      - Include educational content appropriate to the service type
      - Mention location-specific details when relevant
      - Use the business owner's authentic voice and terminology
      - Include job number and specific property details
      - End with appropriate contact information and business signature
      
      Format: Complete professional email ready to send to customer.
    SYSTEM
  end
  
  def build_comprehensive_user_prompt(service_notes:, customer_data:, location_data:, job_data:, business_profile:)
    <<~PROMPT
      Write a customer update email based on the following information:
      
      CUSTOMER INFORMATION:
      - Name: #{customer_data[:name]}
      - Email: #{customer_data[:email]}
      - Property Address: #{location_data[:street]}, #{location_data[:city]}, #{location_data[:state]}
      
      JOB DETAILS:
      - Job Number: #{job_data[:job_number]}
      - Service Date: #{job_data[:service_date] || Date.current.strftime('%B %d, %Y')}
      - Service Type: #{job_data[:service_type]}
      
      SERVICE NOTES FROM TECHNICIAN:
      #{service_notes}
      
      LOCATION CONTEXT:
      - City: #{location_data[:city]}
      - State: #{location_data[:state]}
      - Current season: #{location_data[:current_season]}
      - Regional considerations: #{location_data[:regional_notes]}
      
      BUSINESS CONTEXT:
      - Service offering: #{business_profile[:service_description]}
      - Seasonal considerations for this service: #{business_profile[:seasonal_advice]}
      
      Generate a complete customer update email that:
      1. References the specific service notes and findings
      2. Includes educational content relevant to the service and season
      3. Uses location-specific details (local plants, weather, regional considerations)
      4. Maintains the business's authentic communication style
      5. Includes all necessary business contact information
      6. Provides forward-looking advice or next steps
    PROMPT
  end
  
  def build_generic_system_prompt
    <<~SYSTEM
      You are an expert customer service email writer for field service businesses.
      Write professional, educational customer update emails that are informative and helpful.
      Include specific details from service notes and provide seasonal or maintenance advice.
      
      Format: Email body only, 250-400 words, professional but friendly tone.
    SYSTEM
  end
  
  def mock_response(prompt)
    {
      success: true,
      email_content: generate_mock_business_email,
      usage: { prompt_tokens: 200, completion_tokens: 300, total_tokens: 500 },
      provider: 'mock',
      model: 'mock-business'
    }
  end
  
  def generate_mock_business_email
    <<~EMAIL
      Dear Customer,
      
      We completed your service call today and wanted to provide you with a detailed update on our visit. Our technician conducted a thorough inspection and addressed all items on your service request.
      
      Service Summary:
      Your systems are performing well for this time of year. We completed the scheduled maintenance items and found everything operating within normal parameters. The equipment is handling current seasonal demands effectively.
      
      During our visit, we identified a few minor items that don't require immediate attention but should be monitored over the coming months. These are typical for equipment of this age and usage pattern in your area.
      
      Looking ahead, we recommend staying on the current maintenance schedule to ensure optimal performance through the upcoming season. Your proactive approach to maintenance helps prevent unexpected issues and extends equipment life.
      
      Thank you for choosing our services. If you have any questions about today's service or need additional assistance, please don't hesitate to reach out.
      
      Best regards,
      Your Service Team
      
      [🔧 Mock email - Add GROK_API_KEY to enable real AI generation with business profiles]
    EMAIL
  end
end