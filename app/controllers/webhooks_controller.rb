class WebhooksController < ApplicationController
  def jobber
    puts "=== SERVICEFLOW WEBHOOK RECEIVED ==="
    
    # Get the webhook data (this will be real Jobber data)
    webhook_data = params.except(:controller, :action, :webhook)
    puts "Webhook data: #{webhook_data}"
    
    # Process the data using your enhanced logic
    processed_data = process_jobber_data(webhook_data)
    
    # Generate AI prompt (your n8n logic)
    ai_prompt = generate_ai_prompt(processed_data)
    
puts "Generated AI prompt: #{ai_prompt[:preview]}"

# Generate customer email using AI
ai_response = AiService.generate_customer_email(ai_prompt[:full_prompt])

if ai_response[:success]
  puts "✅ AI Email Generated Successfully!"
  puts "Email preview: #{ai_response[:email_content][0..200]}..."
  
  # TODO: Send email (next step)
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
    
    # Extract data (like your n8n code)
    
    def extract_job_info(data)
  # Handle real Jobber webhook format
  if data[:event] == 'visit.completed'
    visit_data = data[:visit] || {}
    job_data = visit_data[:job] || {}
    property_data = job_data[:property] || {}
    address_data = property_data[:address] || {}
    
    {
      job_number: job_data[:jobNumber] || "SF-#{rand(1000..9999)}",
      property_street: address_data[:street],
      property_city: address_data[:city], 
      property_state: address_data[:province],
      line_items: job_data[:lineItems]&.dig(:nodes)&.map { |item| item[:name] }&.join(", ")
    }
  else
    # Fallback to test format
    {
      job_number: data[:job_number] || "SF-#{rand(1000..9999)}",
      property_street: data[:property_address] || "123 Bee Lane",
      property_city: data[:city] || "Austin",
      property_state: data[:state] || "TX",
      line_items: data[:services] || "Hive inspection"
    }
  end
end
    
    # Get intelligent seasonal context
    property_address = {
      street: job_data[:property_street] || "123 Main St",
      city: job_data[:property_city] || "Austin", 
      province: job_data[:property_state] || "TX"
    }
    
    season_info = SeasonalIntelligenceService.determine_season(
      property_address, 
      'beekeeping' # TODO: Get from business profile
    )
    
    {
      job_id: job_data[:job_number],
      customer_name: customer_data[:display_name],
      customer_email: customer_data[:primary_email],
      property_address: property_address,
      service_notes: notes_data[:formatted_notes],
      season_info: season_info,
      service_items: job_data[:line_items]
    }
  end

  def extract_job_info(data)
    # Simulate extracting job data (real implementation will parse Jobber webhook)
    {
      job_number: data[:job_number] || "SF-#{rand(1000..9999)}",
      property_street: data[:property_address] || "123 Bee Lane",
      property_city: data[:city] || "Austin",
      property_state: data[:state] || "TX",
      line_items: data[:services] || "Hive inspection, mite treatment"
    }
  end

  def extract_customer_info(data)
    # Simulate customer data extraction
    company_name = data[:company_name] || "Hill Country Apiaries"
    first_name = data[:first_name] || "John"
    last_name = data[:last_name] || "Smith"
    
    {
      display_name: company_name.present? ? company_name : "#{first_name} #{last_name}",
      primary_email: data[:email] || "john@hillcountryapiaries.com"
    }
  end

  def extract_and_process_notes(data)
    # Simulate your n8n note processing logic
    raw_notes = data[:notes] || "Inspected 3 hives. Queen present in all. Added supers to hive #2. Mite levels low."
    
    {
      formatted_notes: raw_notes,
      note_count: 1,
      created_date: Date.current.strftime("%m/%d/%Y")
    }
  end

  def generate_ai_prompt(processed_data)
    # Your n8n prompt generation logic
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
    # Your exact n8n prompt logic converted to Ruby
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
  # Mock email sending for now
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
end
