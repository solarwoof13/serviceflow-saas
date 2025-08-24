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
  
  def mock_response(prompt, industry = nil)
    # Try to detect industry from prompt if not provided previous nonte- Replace the mock_response method in ai_service.rb
    if industry.nil? && prompt.present?
      industry = detect_industry_from_prompt(prompt)
    end
    
    {
      success: true,
      email_content: generate_mock_business_email_for_industry(industry || 'general'),
      usage: { prompt_tokens: 200, completion_tokens: 300, total_tokens: 500 },
      provider: 'mock',
      model: 'mock-business'
    }
  end
  
  def detect_industry_from_prompt(prompt)
    prompt_lower = prompt.downcase
    return 'beekeeping' if prompt_lower.include?('hive') || prompt_lower.include?('bee')
    return 'hvac' if prompt_lower.include?('hvac') || prompt_lower.include?('heating')
    return 'landscaping' if prompt_lower.include?('lawn') || prompt_lower.include?('landscape')
    'general'
  end
  
  def generate_mock_business_email_for_industry(industry)
    case industry.to_s.downcase
    when 'beekeeping'
      generate_beekeeping_mock
    when 'hvac'
      generate_hvac_mock
    when 'landscaping'
      generate_landscaping_mock
    else
      generate_general_mock
    end
  end
  
  def generate_beekeeping_mock
    <<~EMAIL
      Dear Hive Host,
      
      I completed today's hive inspection and wanted to share what I observed. Your colony is showing excellent progress for this time of year, with strong population growth and good brood patterns.
      
      Inspection Results:
      The bees are actively foraging and bringing in nectar and pollen. I checked for signs of swarming preparation and found the colony has adequate space with proper ventilation. The queen is laying well, and I observed healthy capped brood across multiple frames.
      
      Current Status:
      All hive components are in good condition with no signs of disease or pest issues. The colony strength is appropriate for the current season, and honey stores are building nicely. I noticed good bee activity and traffic at the entrance.
      
      Next Steps:
      With the current nectar flow, your bees should continue building up their winter stores. I'll monitor the hive's progress and watch for any seasonal changes that might affect their behavior.
      
      Thank you for hosting a hive and supporting local pollinators. Your commitment to sustainable beekeeping practices helps maintain strong, healthy colonies.
      
      Best regards,
      Your Beekeeper
      
      [🐝 Mock beekeeping email - Add GROK_API_KEY to enable real AI generation]
    EMAIL
  end
  
  def generate_hvac_mock
    <<~EMAIL
      Dear Customer,
      
      We completed your HVAC service today and wanted to provide you with a detailed summary of our work and system status.
      
      Service Summary:
      Your heating and cooling system has been thoroughly inspected and serviced. All components are operating efficiently and should provide reliable comfort throughout the season. Safety checks have been completed and passed.
      
      System Status:
      The equipment is performing within optimal parameters. We've cleaned filters, checked refrigerant levels, and verified proper airflow throughout the system. All electrical connections are secure and functioning properly.
      
      Recommendations:
      Your system is in good condition. Continue with regular maintenance to ensure peak efficiency and prevent unexpected breakdowns. The next service should be scheduled according to your maintenance plan.
      
      Thank you for choosing our HVAC services. Please contact us if you have any questions about today's work.
      
      Best regards,
      Your HVAC Service Team
      
      [🔧 Mock HVAC email - Add GROK_API_KEY to enable real AI generation]
    EMAIL
  end
  
  def generate_landscaping_mock
    <<~EMAIL
      Dear Customer,
      
      We completed your landscaping service today and wanted to update you on the work performed and your property's current condition.
      
      Service Summary:
      All scheduled landscaping work has been completed successfully. Your lawn and garden areas have been maintained according to current seasonal needs and are showing healthy growth patterns.
      
      Property Status:
      The landscape is responding well to our care program. Plants are thriving in the current weather conditions, and we've made seasonal adjustments to support optimal plant health and appearance.
      
      Seasonal Care:
      We've adapted our approach based on current growing conditions in your area. Your property should continue to look its best with regular maintenance and seasonal treatments.
      
      Thank you for trusting us with your landscape care. Please let us know if you have any questions or special requests for future visits.
      
      Best regards,
      Your Landscape Team
      
      [🌱 Mock landscaping email - Add GROK_API_KEY to enable real AI generation]
    EMAIL
  end
  
  def generate_general_mock
    <<~EMAIL
      Dear Customer,
      
      We completed your service call today and wanted to provide you with an update on the work performed.
      
      Service Summary:
      All requested services have been completed successfully according to our quality standards. We conducted a thorough inspection and addressed all items on your service request.
      
      Work Status:
      Everything is functioning properly and should provide reliable performance. We've made any necessary adjustments to ensure optimal operation appropriate for current conditions.
      
      Follow-up:
      Based on today's service, your systems are in good working order. We recommend following the regular maintenance schedule to maintain peak performance.
      
      Thank you for choosing our services. Please contact us if you have any questions about today's work or need additional assistance.
      
      Best regards,
      Your Service Team
      
      [🔧 Mock service email - Add GROK_API_KEY to enable real AI generation]
    EMAIL
  end
end