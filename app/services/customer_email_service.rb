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
    
    # FIX: Load the actual business profile from the database
    business_profile = load_business_profile(processed_data)
    
    # Convert processed_data to visit_data format
    visit_data = {
      business_profile: business_profile,
      customer_name: processed_data[:customer_name],
      customer_location: "#{processed_data[:property_address][:city]}, #{processed_data[:property_address][:province]}",
      visit_notes: processed_data[:service_notes],
      visit_date: Date.current,
      customer_email: processed_data[:customer_email],
      service_type: processed_data[:service_type] || business_profile&.main_service_type
    }
    
    # Generate the email
    email_result = generate_visit_follow_up(visit_data)
    
    if email_result[:success]
      # FIX: Dynamic from name based on service type
      from_name = determine_from_name(business_profile&.main_service_type)
      
      # Send the email using EmailService
      send_result = EmailService.send_customer_email(
        to: processed_data[:customer_email],
        subject: email_result[:subject],
        content: email_result[:email_content],
        from_name: from_name
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

  # ADD: Method to load business profile
  def load_business_profile(processed_data)
    # Try to find the business profile based on the webhook data
    # This assumes you have a way to link the webhook to the correct business profile
    
    # Option 1: If you have jobber_account_id in processed_data
    if processed_data[:jobber_account_id]
      jobber_account = JobberAccount.find_by(jobber_id: processed_data[:jobber_account_id])
      return jobber_account&.service_provider_profile
    end
    
    # Option 2: If you store profile_id in session or webhook data
    if processed_data[:profile_id]
      return ServiceProviderProfile.find_by(id: processed_data[:profile_id])
    end
    
    # Option 3: Default to the most recent profile (for testing)
    Rails.logger.warn "⚠️ No business profile found for webhook, using fallback"
    ServiceProviderProfile.last
  end

  # ADD: Dynamic from name method
  def determine_from_name(service_type)
    case service_type&.downcase
    when 'beekeeping services', 'beekeeping'
      "Host a Hive Beekeeping Services"
    when 'plumbing'
      "Professional Plumbing Services"
    when 'hvac services', 'hvac'
      "Expert HVAC Services"
    when 'snow removal'
      "Reliable Snow Removal Services"
    when 'lawn care & maintenance'
      "Professional Lawn Care Services"
    when 'pest control'
      "Expert Pest Control Services"
    when 'cleaning services'
      "Professional Cleaning Services"
    when 'electrical'
      "Licensed Electrical Services"
    when 'landscaping'
      "Professional Landscaping Services"
    else
      "#{service_type || 'Professional Service'} Team"
    end
  end
  
  private
  
  def build_visit_email_prompt(business_profile:, customer_name:, customer_location:, visit_notes:, service_type:, visit_date:)
    month = visit_date.strftime('%B')
    day = visit_date.strftime('%d')
    
    # Dynamic service-type specific system prompt
    system_prompt = build_dynamic_system_prompt(service_type)
    
    prompt = "#{system_prompt}\n\n"
    
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
      
      # Seasonal Services (if applicable)
      seasonal_info = build_seasonal_context(business_profile, service_type, month)
      prompt += "#{seasonal_info}\n" if seasonal_info.present?
    end
    
    # Visit Details
    prompt += "VISIT INFORMATION:\n"
    prompt += "Customer: #{customer_name}\n"
    prompt += "Location: #{customer_location}\n"
    prompt += "Service Date: #{month} #{day}\n"
    prompt += "Work Completed: #{visit_notes}\n\n"
    
    # Smart Instructions based on service type
    prompt += build_service_specific_instructions(service_type, business_profile, month, customer_location)
    
    prompt += "\nGenerate a complete customer follow-up email that demonstrates expert #{service_type&.downcase || 'service'} knowledge."
    
    prompt
  end

  def build_dynamic_system_prompt(service_type)
    case service_type&.downcase
    when 'beekeeping services', 'beekeeping'
      "You are an experienced beekeeping business owner with expertise in hive management, honey production, and treatment-free practices. You provide turn-key subscription services where your professional team manages hives at customer locations."
    when 'plumbing'
      "You are a licensed plumbing professional with years of experience in residential and commercial plumbing systems, repairs, and installations. You understand water systems, drainage, and local plumbing codes."
    when 'hvac services', 'hvac'
      "You are an HVAC specialist with expertise in heating, ventilation, and air conditioning systems, maintenance, and energy-efficient solutions. You understand climate control and indoor air quality."
    when 'snow removal'
      "You are a snow removal professional specializing in safe, efficient snow clearing for residential and commercial properties. You understand winter weather patterns and safety protocols."
    when 'lawn care & maintenance'
      "You are a lawn care specialist with expertise in turf management, seasonal maintenance, and sustainable landscaping practices. You understand local soil conditions and plant health."
    when 'pest control'
      "You are a pest control professional with expertise in integrated pest management, safe treatment methods, and prevention strategies. You understand local pest species and environmental considerations."
    when 'cleaning services'
      "You are a professional cleaning service provider with expertise in residential and commercial cleaning, sanitation, and maintenance. You understand different cleaning methods and equipment."
    when 'electrical'
      "You are a licensed electrician with expertise in electrical systems, safety codes, and energy-efficient solutions. You understand wiring, circuits, and electrical safety."
    when 'landscaping'
      "You are a landscaping professional with expertise in design, installation, and maintenance of outdoor spaces. You understand plant selection, hardscaping, and seasonal care."
    else
      "You are an expert #{service_type&.downcase || 'service'} contractor with years of experience providing professional services to customers in your local area."
    end
  end

  def build_seasonal_context(business_profile, service_type, month)
    return nil unless business_profile
    
    seasonal_data = []
    
    # Only include seasonal info for relevant service types
    case service_type&.downcase
    when 'beekeeping services', 'beekeeping', 'lawn care & maintenance', 'landscaping', 'snow removal'
      if business_profile.spring_services.present? && ['March', 'April', 'May'].include?(month)
        seasonal_data << "Spring Services: #{business_profile.spring_services}"
      end
      if business_profile.summer_services.present? && ['June', 'July', 'August'].include?(month)
        seasonal_data << "Summer Services: #{business_profile.summer_services}"
      end
      if business_profile.fall_services.present? && ['September', 'October', 'November'].include?(month)
        seasonal_data << "Fall Services: #{business_profile.fall_services}"
      end
      if business_profile.winter_services.present? && ['December', 'January', 'February'].include?(month)
        seasonal_data << "Winter Services: #{business_profile.winter_services}"
      end
    end
    
    if seasonal_data.any?
      "SEASONAL CONTEXT:\n#{seasonal_data.join("\n")}\n\n"
    else
      nil
    end
  end

  def build_service_specific_instructions(service_type, business_profile, month, customer_location)
    instructions = "\n\nSERVICE-SPECIFIC REQUIREMENTS:\n"
    
    case service_type&.downcase
    when 'beekeeping services', 'beekeeping'
      instructions += "- Emphasize your turn-key subscription model and professional beekeeping team\n"
      instructions += "- Reference honey production and seasonal hive management\n"
      instructions += "- Include treatment-free practices and genetic expertise\n"
      instructions += "- Mention seasonal considerations for #{month} in #{customer_location}\n"
    when 'plumbing'
      instructions += "- Reference specific plumbing work completed and materials used\n"
      instructions += "- Include water conservation or efficiency tips\n"
      instructions += "- Mention local water quality considerations for #{customer_location}\n"
      instructions += "- Add seasonal plumbing advice for #{month}\n"
    when 'hvac services', 'hvac'
      instructions += "- Discuss system efficiency and energy savings\n"
      instructions += "- Include seasonal maintenance recommendations for #{month}\n"
      instructions += "- Reference local climate considerations for #{customer_location}\n"
      instructions += "- Mention indoor air quality improvements\n"
    when 'snow removal'
      instructions += "- Emphasize safety and thoroughness of snow removal\n"
      instructions += "- Include ice prevention and de-icing recommendations\n"
      instructions += "- Reference local weather patterns for #{customer_location} in #{month}\n"
      instructions += "- Mention equipment used and professional techniques\n"
    when 'lawn care & maintenance'
      instructions += "- Reference specific lawn care treatments or maintenance performed\n"
      instructions += "- Include seasonal lawn care tips for #{month}\n"
      instructions += "- Mention local soil or climate considerations for #{customer_location}\n"
      instructions += "- Add recommendations for ongoing lawn health\n"
    when 'pest control'
      instructions += "- Reference specific pest issues addressed and treatments used\n"
      instructions += "- Include prevention tips and seasonal pest considerations for #{month}\n"
      instructions += "- Mention local pest species common in #{customer_location}\n"
      instructions += "- Add recommendations for ongoing pest management\n"
    when 'cleaning services'
      instructions += "- Reference specific cleaning services provided\n"
      instructions += "- Include cleaning frequency recommendations\n"
      instructions += "- Mention any specialty cleaning methods or products used\n"
      instructions += "- Add tips for maintaining cleanliness\n"
    when 'electrical'
      instructions += "- Reference specific electrical work completed\n"
      instructions += "- Include safety tips and electrical maintenance advice\n"
      instructions += "- Mention energy efficiency improvements if applicable\n"
      instructions += "- Add recommendations for electrical system maintenance\n"
    when 'landscaping'
      instructions += "- Reference specific landscaping work completed\n"
      instructions += "- Include seasonal plant care tips for #{month}\n"
      instructions += "- Mention local plant species suitable for #{customer_location}\n"
      instructions += "- Add recommendations for ongoing landscape maintenance\n"
    else
      instructions += "- Reference the specific #{service_type&.downcase} work completed\n"
      instructions += "- Include relevant seasonal or local considerations for #{month} in #{customer_location}\n"
      instructions += "- Demonstrate expertise in #{service_type&.downcase} services\n"
      instructions += "- Provide helpful next steps or maintenance recommendations\n"
    end
    
    instructions
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
            content: 'You are an expert contractor or service provider writing professional follow-up emails. Use your knowledge of seasons, weather, and regional conditions to provide valuable, location-specific advice that is relavent to the type of service provided. Always include a clear subject line at the start.'
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