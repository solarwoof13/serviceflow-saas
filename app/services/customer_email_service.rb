# Create file: app/services/customer_email_service.rb
class CustomerEmailService
  include HTTParty
  
  def initialize
    @api_key = ENV['GROK_API_KEY']
    @api_url = ENV['GROK_API_URL'] || 'https://api.x.ai/v1/chat/completions'
    @model = ENV['GROK_MODEL'] || 'grok-4-0709'
    @temperature = ENV['GROK_TEMPERATURE']&.to_f || 0.3
  end
  
  def generate_visit_follow_up(visit_data)
    # Extract visit information
    business_profile = visit_data[:business_profile]
    customer_name = visit_data[:customer_name]
    customer_location = visit_data[:customer_location]
    visit_notes = visit_data[:visit_notes]
    visit_date = visit_data[:visit_date] || Date.current
    service_type = business_profile&.main_service_type || 'General Service'
    
    # Build intelligent prompt
    prompt = build_visit_email_prompt(
      business_profile: business_profile,
      customer_name: customer_name,
      customer_location: customer_location,
      visit_notes: visit_notes,
      service_type: service_type,
      visit_date: visit_date
    )
    
    # Generate with AI
    result = call_grok_api(prompt)
    
    if result[:success]
      email_content = result[:content]
      {
        success: true,
        email_content: email_content,
        subject: extract_subject_line(email_content),
        generated_at: Time.current
      }
    else
      # Fallback to basic template
      {
        success: false,
        email_content: generate_fallback_email(visit_data),
        subject: "Service Update - #{visit_date.strftime('%B %d')}",
        error: result[:error],
        generated_at: Time.current
      }
    end
  end
  
  private
  
  def build_visit_email_prompt(business_profile:, customer_name:, customer_location:, visit_notes:, service_type:, visit_date:)
    month = visit_date.strftime('%B')
    day = visit_date.strftime('%d')
    
    prompt = "You are writing a professional follow-up email as an expert #{service_type.downcase} contractor to a customer after completing service.\n\n"
    
    # Business Intelligence from Enhanced Signup
    if business_profile
      prompt += "BUSINESS CONTEXT (use this to sound authentic and expert):\n"
      prompt += "Company: #{business_profile.company_name}\n"
      prompt += "Business Description: #{business_profile.company_description}\n"
      prompt += "Service Expertise: #{business_profile.service_details}\n"
      prompt += "What Makes Us Different: #{business_profile.unique_selling_points}\n"
      prompt += "Local Knowledge: #{business_profile.local_expertise}\n"
      prompt += "Years in Business: #{business_profile.years_in_business}\n"
      prompt += "Communication Style: #{business_profile.email_tone} tone\n\n"
    end
    
    # Visit Details
    prompt += "VISIT INFORMATION:\n"
    prompt += "Customer: #{customer_name}\n"
    prompt += "Location: #{customer_location}\n"
    prompt += "Service Date: #{month} #{day}\n"
    prompt += "Work Completed: #{visit_notes}\n\n"
    
    # Smart Instructions
    prompt += "EMAIL REQUIREMENTS:\n"
    prompt += "1. Write as the business owner/expert contractor (use the business context above)\n"
    prompt += "2. Reference the specific work completed from visit notes\n"
    prompt += "3. Use your knowledge of #{customer_location} location and #{month} timing to add relevant seasonal advice\n"
    prompt += "4. Include location-specific considerations (weather, local conditions, regional factors)\n"
    prompt += "5. Add professional tips that demonstrate your #{service_type.downcase} expertise\n"
    prompt += "6. Sound knowledgeable and experienced, not salesy\n"
    prompt += "7. Use #{business_profile&.email_tone || 'professional'} tone\n"
    prompt += "8. Include helpful next steps or maintenance recommendations\n"
    prompt += "9. Start with a clear subject line\n"
    prompt += "10. Keep it concise but valuable (2-3 paragraphs max)\n\n"
    
    # Service-Specific Intelligence Request
    prompt += "SPECIFIC REQUESTS:\n"
    case service_type.downcase
    when /beekeeping/
      prompt += "- Consider seasonal bee activity for #{month} in #{customer_location}\n"
      prompt += "- Mention relevant nectar sources or hive conditions for this time of year\n"
      prompt += "- Include regional beekeeping considerations\n"
    when /hvac/
      prompt += "- Consider seasonal HVAC needs for #{month} in #{customer_location}\n"
      prompt += "- Mention relevant heating/cooling advice for this time of year\n"
      prompt += "- Include energy efficiency tips for the region\n"
    when /plumbing/
      prompt += "- Consider seasonal plumbing concerns for #{month} in #{customer_location}\n"
      prompt += "- Mention freeze protection or seasonal maintenance for this time of year\n"
      prompt += "- Include regional plumbing considerations\n"
    when /landscaping/, /lawn/
      prompt += "- Consider seasonal landscaping needs for #{month} in #{customer_location}\n"
      prompt += "- Mention relevant plant care or lawn maintenance for this time of year\n"
      prompt += "- Include regional growing considerations\n"
    when /electrical/
      prompt += "- Consider seasonal electrical safety for #{month} in #{customer_location}\n"
      prompt += "- Mention relevant electrical considerations for this time of year\n"
      prompt += "- Include regional electrical concerns\n"
    else
      prompt += "- Consider seasonal maintenance needs for #{month} in #{customer_location}\n"
      prompt += "- Mention relevant service considerations for this time of year\n"
      prompt += "- Include regional service factors\n"
    end
    
    prompt += "\nGenerate a complete customer follow-up email that demonstrates expert #{service_type.downcase} knowledge."
    
    prompt
  end
  
  def call_grok_api(prompt)
    return { success: false, error: 'API key not configured' } unless @api_key.present?
    
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
            content: 'You are an expert contractor writing professional follow-up emails. Use your knowledge of seasons, weather, and regional conditions to provide valuable, location-specific advice. Always include a clear subject line at the start.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 1000,
        temperature: @temperature
      }.to_json
    })
    
    if response.success?
      content = response.parsed_response.dig('choices', 0, 'message', 'content')
      { success: true, content: content }
    else
      Rails.logger.error "Customer email generation failed: #{response.body}"
      { success: false, error: "API error: #{response.code}" }
    end
  rescue => e
    Rails.logger.error "Customer email API error: #{e.message}"
    { success: false, error: e.message }
  end
  
  def extract_subject_line(email_content)
    # Look for subject line at start
    if email_content.match(/^Subject:\s*(.+)$/i)
      return $1.strip
    end
    
    # Look for first line if it looks like a subject
    lines = email_content.split("\n")
    first_line = lines.first&.strip
    
    if first_line && first_line.length < 80 && !first_line.include?(',') && !first_line.include?('Dear')
      return first_line
    end
    
    # Default fallback
    "Service Update - #{Date.current.strftime('%B %d')}"
  end
  
  def generate_fallback_email(visit_data)
    business_name = visit_data[:business_profile]&.company_name || 'Our Team'
    customer_name = visit_data[:customer_name]
    service_type = visit_data[:business_profile]&.main_service_type || 'service'
    visit_date = visit_data[:visit_date]&.strftime('%B %d, %Y') || Date.current.strftime('%B %d, %Y')
    visit_notes = visit_data[:visit_notes]
    
    "Subject: #{service_type} Service Completed - #{visit_date}\n\n" +
    "Dear #{customer_name},\n\n" +
    "Thank you for choosing #{business_name} for your #{service_type.downcase} needs. " +
    "We completed your service on #{visit_date}.\n\n" +
    "Work completed:\n#{visit_notes}\n\n" +
    "If you have any questions about the work performed or need additional service, " +
    "please don't hesitate to contact us.\n\n" +
    "Best regards,\n#{business_name}"
  end
end