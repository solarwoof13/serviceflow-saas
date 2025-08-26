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
  
  # ADD: Missing method that webhooks_controller.rb is trying to call
  def generate_and_send_enhanced_email(processed_data)
    Rails.logger.info "🔄 CustomerEmailService: Generating enhanced email..."
    
    # Convert processed_data to visit_data format
    visit_data = {
      business_profile: nil, # You may want to load this from a config or database
      customer_name: processed_data[:customer_name],
      customer_location: "#{processed_data[:property_address][:city]}, #{processed_data[:property_address][:province]}",
      visit_notes: processed_data[:service_notes],
      visit_date: Date.current,
      customer_email: processed_data[:customer_email]
    }
    
    # Generate the email
    email_result = generate_visit_follow_up(visit_data)
    
    if email_result[:success]
      # Send the email using EmailService
      send_result = EmailService.send_customer_email(
        to: processed_data[:customer_email],
        subject: email_result[:subject],
        content: email_result[:email_content],
        from_name: "Host a Hive Beekeeping Services"
      )
      
      Rails.logger.info email_result[:success] ? "✅ Enhanced email sent!" : "❌ Enhanced email failed: #{send_result[:error]}"
      
      return {
        email_generated: email_result[:success],
        email_sent: send_result[:success],
        email_content: email_result[:email_content],
        send_result: send_result
      }
    else
      Rails.logger.error "❌ Email generation failed: #{email_result[:error]}"
      return {
        email_generated: false,
        email_sent: false,
        error: email_result[:error]
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
        max_tokens: 2000,
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
    # Look for subject line at start and REMOVE it from content
    if email_content.match(/^Subject:\s*(.+)$/i)
      subject = $1.strip
      # Remove the subject line from the email content
      email_content.gsub!(/^Subject:\s*.+\n\n?/i, '')
      return subject
    end
    
    # Default fallback
    "Service Update - #{Date.current.strftime('%B %d')}"
  end
  
  def generate_fallback_email(visit_data)
    business_profile = visit_data[:business_profile]
    customer_name = visit_data[:customer_name]
    visit_notes = visit_data[:visit_notes]
    visit_date = visit_data[:visit_date]&.strftime('%B %d, %Y') || Date.current.strftime('%B %d, %Y')
    
    # Extract business info with fallbacks
    business_name = business_profile&.company_name || 'Our Team'
    service_type = business_profile&.main_service_type || 'service'
    
    # Build signature with cascading fallbacks
    signature = build_signature(business_profile)
    
    "Subject: #{service_type} Service Completed - #{visit_date}\n\n" +
    "Dear #{customer_name},\n\n" +
    "Thank you for choosing #{business_name} for your #{service_type.downcase} needs. " +
    "We completed your service on #{visit_date}.\n\n" +
    "Work completed:\n#{visit_notes}\n\n" +
    "If you have any questions about the work performed or need additional service, " +
    "please don't hesitate to contact us.\n\n" +
    "#{signature}"
  end

  def build_signature(business_profile)
    return "Best regards,\nOur Team" unless business_profile
    
    signature_parts = ["Best regards,"]
    
    # Try to extract owner name from company description
    owner_name = extract_owner_name(business_profile)
    if owner_name
      signature_parts << owner_name
      signature_parts << "#{business_profile.company_name}"
    else
      signature_parts << "#{business_profile.company_name} Team"
    end
    
    # Add contact info if available
    contact_info = extract_contact_info(business_profile)
    signature_parts << contact_info if contact_info.present?
    
    signature_parts.join("\n")
  end

  def extract_owner_name(business_profile)
    # Try multiple extraction methods
    desc = business_profile.company_description || ""
    
    # Look for owner mentions in description
    if match = desc.match(/(?:owner|founded by|started by)[:\s]+([A-Z][a-z]+\s+[A-Z][a-z]+)/i)
      return match[1]
    end
    
    # Look for "I am" or "My name is" patterns
    if match = desc.match(/(?:I am|My name is)[:\s]+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)/i)
      return match[1]
    end
    
    # Extract from company name if it contains a person's name
    company = business_profile.company_name || ""
    if company.match?(/^[A-Z][a-z]+\s+[A-Z][a-z]+/)
      return company.split(/\s+/).first(2).join(' ')
    end
    
    nil # No owner name found
  end

  def extract_contact_info(business_profile)
    contact_parts = []
    
    # Add certifications/licenses as contact context
    if business_profile.certifications_licenses.present?
      contact_parts << business_profile.certifications_licenses
    end
    
    # Add service area info
    if business_profile.local_expertise.present?
      expertise = business_profile.local_expertise
      if expertise.length < 100 # Only if it's brief
        contact_parts << "Serving: #{expertise}"
      end
    end
    
    contact_parts.join("\n")
  end
end