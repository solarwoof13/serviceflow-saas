class WebhooksController < ApplicationController
  def jobber
    puts "=== SERVICEFLOW WEBHOOK RECEIVED ==="
    
    webhook_data = params.except(:controller, :action, :webhook)
    puts "Webhook data: #{webhook_data}"
    
    processed_data = process_jobber_data(webhook_data)
    ai_prompt = generate_ai_prompt(processed_data)
    
    puts "Generated AI prompt: #{ai_prompt[:preview]}"

    ai_response = AiService.generate_customer_email(ai_prompt[:full_prompt])

    if ai_response[:success]
      puts "✅ AI Email Generated Successfully!"
      puts "Email preview: #{ai_response[:email_content][0..200]}..."
      
      email_sent = send_customer_email(
        to: processed_data[:customer_email],
        subject: "Service Update for #{processed_data[:customer_name]}",
        content: ai_response[:email_content]
      )
      
      puts email_sent[:success] ? "✅ Email sent!" : "❌ Email failed: #{email_sent[:error]}"
    else
      puts "❌ AI generation failed: #{ai_response[:error]}"
    end
    
    render json: { 
      status: 'processed',
      job_id: processed_data[:job_id],
      customer: processed_data[:customer_name],
      season: processed_data[:season_info],
      prompt_ready: true
    }
  rescue => e
    puts "Error processing webhook: #{e.message}"
    puts e.backtrace
    render json: { error: e.message }, status: 500
  end

  private

  def process_jobber_data(data)
    puts "Processing Jobber data for automation..."
    
    # Extract visit ID from real Jobber webhook
    visit_id = data.dig("data", "webHookEvent", "itemId")
    
    if visit_id
      puts "Found visit ID: #{visit_id}"
      
      # Get access token for this account
      access_token = get_access_token_for_account
      
      # ADD: Test API connection before making the real call
      if JobberApiService.test_connection(access_token)
        puts "✅ API connection verified - proceeding with visit query"
      else
        puts "❌ API connection failed - check token and permissions"
      end
      
      # Fetch real data from Jobber
      puts "🔍 Calling Jobber API with visit_id: #{visit_id}"
      puts "🔑 Token (first 20 chars): #{access_token[0..20]}..." if access_token

      begin
        jobber_data = JobberApiService.fetch_visit_details(visit_id, access_token)
        puts "📡 Raw Jobber API response: #{jobber_data.inspect}"
        
        if jobber_data.nil?
          puts "❌ API returned nil - possible authentication or permissions issue"
        elsif jobber_data.is_a?(Hash) && jobber_data['error']
          puts "❌ API returned error: #{jobber_data['error']}"
        elsif jobber_data.is_a?(Hash) && jobber_data['errors']
          puts "❌ GraphQL errors: #{jobber_data['errors'].inspect}"
        else
          puts "✅ API returned data structure: #{jobber_data.keys if jobber_data.is_a?(Hash)}"
        end
      rescue => e
        puts "💥 Exception calling Jobber API: #{e.message}"
        puts "📚 Backtrace: #{e.backtrace[0..2]}"
        jobber_data = nil
      end

      if jobber_data && jobber_data['id'] && !jobber_data['error']
        puts "✅ Successfully fetched real Jobber data"
        job_info = extract_real_job_info(jobber_data['data']['visit'])
        customer_info = extract_real_customer_info(jobber_data['data']['visit'])
        notes_info = extract_real_notes(jobber_data['data']['visit'])
      else
        puts "❌ Failed to fetch Jobber data, using fallback"
        job_info = extract_job_info(data)
        customer_info = extract_customer_info(data)
        notes_info = extract_and_process_notes(data)
      end
    else
      puts "No visit ID found, using test data"
      job_info = extract_job_info(data)
      customer_info = extract_customer_info(data)
      notes_info = extract_and_process_notes(data)
    end
    
    property_address = {
      street: job_info[:property_street],
      city: job_info[:property_city], 
      province: job_info[:property_state]
    }
    
    season_info = SeasonalIntelligenceService.determine_season(
      property_address, 
      'beekeeping'
    )
    
    {
      job_id: job_info[:job_number],
      customer_name: customer_info[:display_name],
      customer_email: customer_info[:primary_email],
      property_address: property_address,
      service_notes: notes_info[:formatted_notes],
      season_info: season_info,
      service_items: job_info[:line_items]
    }
  end

  def extract_job_info(data)
    {
      job_number: data[:job_number] || data["job_number"] || "SF-#{rand(1000..9999)}",
      property_street: data[:property_address] || data["property_address"] || "123 Bee Lane",
      property_city: data[:city] || data["city"] || "Austin",
      property_state: data[:state] || data["state"] || "TX",
      line_items: data[:services] || data["services"] || "Hive inspection"
    }
  end

  def extract_customer_info(data)
    company_name = data[:company_name] || data["company_name"]
    first_name = data[:first_name] || data["first_name"] || "John"
    last_name = data[:last_name] || data["last_name"] || "Smith"
    email = data[:email] || data["email"] || "customer@example.com"
    
    display_name = if company_name.present?
      company_name
    else
      "#{first_name} #{last_name}".strip
    end
    
    {
      display_name: display_name,
      primary_email: email
    }
  end

  def extract_and_process_notes(data)
    raw_notes = data[:notes] || data["notes"] || "Service completed successfully."
    
    {
      formatted_notes: raw_notes,
      note_count: 1,
      created_date: Date.current.strftime("%m/%d/%Y")
    }
  end

  def generate_ai_prompt(processed_data)
    season = processed_data[:season_info][:season]
    reasoning = processed_data[:season_info][:reasoning]
    
    prompt = build_dynamic_prompt(
      customer_name: processed_data[:customer_name],
      property_address: processed_data[:property_address],
      current_season: season,
      service_notes: processed_data[:service_notes],
      seasonal_reasoning: reasoning
    )
    
    {
      full_prompt: prompt,
      preview: prompt[0..200] + "..."
    }
  end

  def build_dynamic_prompt(customer_name:, property_address:, current_season:, service_notes:, seasonal_reasoning:)
    address_str = "#{property_address[:street]}, #{property_address[:city]}, #{property_address[:province]}"
    
    <<~PROMPT
      Write the actual customer update email content for #{customer_name} who hosts a hive at #{address_str}.

      Current season: #{current_season}
      Current date: #{Date.current.strftime("%m/%d/%Y")}
      Seasonal context: #{seasonal_reasoning}
      Recent beekeeper service notes: "#{service_notes}"

      IMPORTANT SEASONAL LOGIC: 
      Focus on activities appropriate for #{current_season} in #{property_address[:province]}. 
      Use only seasonally appropriate details from the service notes. 
      Include specific seasonal bee behavior and hive management activities.
      Mention our treatment-free approach with mite-resistant genetics. 
      Keep it educational about bee behavior and hive health. 
      Write only the email body content - no subject line, greeting or regards.
    PROMPT
  end

  def send_customer_email(to:, subject:, content:)
    puts "📧 SENDING EMAIL:"
    puts "To: #{to}"
    puts "Subject: #{subject}"
    puts "Content: #{content[0..100]}..."
    
    {
      success: true,
      message: "Email sent successfully (mock)",
      email_id: "sf_#{SecureRandom.hex(8)}"
    }
  end

  def extract_real_job_info(visit_data)
    job_data = visit_data['job'] || {}
    property_data = job_data['property'] || {}
    address_data = property_data['address'] || {}
    line_items = job_data['lineItems']&.dig('nodes') || []
    
    {
      job_number: job_data['jobNumber'] || "SF-#{rand(1000..9999)}",
      property_street: address_data['street'] || "123 Service Lane",
      property_city: address_data['city'] || "Austin",
      property_state: address_data['province'] || "TX",
      line_items: line_items.map { |item| item['name'] }.join(", ")
    }
  end

  def extract_real_customer_info(visit_data)
    job_data = visit_data['job'] || {}
    client_data = job_data['client'] || {}
    emails = client_data['emails'] || []
    
    company_name = client_data['companyName']
    first_name = client_data['firstName'] || "Customer"
    last_name = client_data['lastName'] || ""
    
    primary_email = emails.find { |email| email['primary'] }&.dig('address') || 
                    emails.first&.dig('address') || 
                    "customer@example.com"
    
    display_name = if company_name.present?
      company_name
    else
      "#{first_name} #{last_name}".strip
    end
    
    {
      display_name: display_name,
      primary_email: primary_email
    }
  end

  def extract_real_notes(visit_data)
    notes = visit_data['notes']&.dig('nodes') || []
    
    recent_notes = notes.map do |note|
      "#{note['message']} (#{Date.parse(note['createdAt']).strftime('%m/%d/%Y')})"
    end.join('\n\n')
    
    {
      formatted_notes: recent_notes.present? ? recent_notes : "Service completed successfully.",
      note_count: notes.length,
      created_date: Date.current.strftime("%m/%d/%Y")
    }
  end

  def get_access_token_for_account
    # First try environment variable (for production)
    env_token = ENV['JOBBER_ACCESS_TOKEN']
    if env_token.present?
      puts "✅ Using environment token (manual mode)"
      return env_token
    end
    
    # Use database with auto-refresh
    account = JobberAccount.first
    
    if account
      puts "🔍 Found JobberAccount, checking token validity..."
      token = account.get_valid_access_token
      
      if token
        puts "✅ Got valid access token (auto-refreshed if needed)"
        return token
      else
        puts "❌ Token refresh failed - account needs re-authorization"
        return nil
      end
    else
      puts "❌ No JobberAccount found"
      return nil
    end
  end
end
