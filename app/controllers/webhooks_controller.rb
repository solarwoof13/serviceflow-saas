# app/controllers/webhooks_controller.rb
class WebhooksController < ApplicationController
  def jobber
    puts "=== SERVICEFLOW WEBHOOK RECEIVED ==="
    
    webhook_data = params.except(:controller, :action, :webhook)
    webhook_topic = webhook_data.dig("data", "webHookEvent", "topic")
    visit_id = webhook_data.dig("data", "webHookEvent", "itemId")

    puts "Webhook topic: #{webhook_topic}"
    puts "Visit ID: #{visit_id}"
    puts "Webhook data: #{webhook_data}"
    
    # Get the JobberAccount for this webhook with enhanced identification
    jobber_account = get_jobber_account_for_webhook(webhook_data)
    
    unless jobber_account
      puts "❌ No JobberAccount found - using fallback processing"
      render json: { error: 'Account not found' }, status: :not_found
      return
    end
    
    # Process with enhanced business intelligence
    processed_data = process_jobber_data_enhanced(webhook_data, jobber_account)

    # 🛡️ SAFETY CHECK: Should we send an email for this webhook?
    safety_check = EmailSafetyService.safe_to_send_email?(
      visit_id: visit_id,
      customer_email: processed_data[:customer_email],
      webhook_data: webhook_data
    )

    unless safety_check[:safe]
      puts "🚫 Email blocked: #{safety_check[:reason]}"
      render json: { 
        status: 'blocked',
        reason: safety_check[:reason],
        visit_id: visit_id,
        webhook_topic: webhook_topic
      }
      return
    end

    puts "✅ Safety check passed: #{safety_check[:reason]}"
    
    # Generate AI email using new CustomerEmailService
    email_result = generate_and_send_enhanced_email(processed_data, jobber_account)
    
    if email_result[:success]
      puts "✅ Enhanced AI Email Generated and Sent!"
      puts "Email subject: #{email_result[:subject]}"
      puts "Email preview: #{email_result[:email_content][0..200]}..."
    else
      puts "❌ Enhanced email generation failed: #{email_result[:error]}"
    end
    
    render json: { 
      status: 'processed',
      job_id: processed_data[:job_id],
      customer: processed_data[:customer_name],
      business_profile_used: jobber_account.service_provider_profile.present?,
      ai_generated: email_result[:success],
      email_sent: email_result[:email_sent],
      account_used: jobber_account.name
    }
  rescue => e
    puts "Error processing webhook: #{e.message}"
    puts e.backtrace
    render json: { error: e.message }, status: 500
  end

  private

  def get_jobber_account_for_webhook(webhook_data)
    Rails.logger.info "🔍 Identifying JobberAccount from webhook..."
    
    # Extract account ID from correct webhook structure
    webhook_account_id = webhook_data.dig("data", "webHookEvent", "accountId")
    
    if webhook_account_id.present?
      Rails.logger.info "📡 Webhook contains account ID: #{webhook_account_id}"
      account = JobberAccount.find_by(jobber_id: webhook_account_id)
      
      if account
        Rails.logger.info "✅ Found JobberAccount: #{account.name}"
        puts "✅ Found JobberAccount: #{account.name}"
        return account
      else
        Rails.logger.warn "⚠️ No JobberAccount found for jobber_id: #{webhook_account_id}"
        puts "⚠️ No JobberAccount found for jobber_id: #{webhook_account_id}"
      end
    else
      Rails.logger.info "📡 No account ID in webhook, will fetch from API..."
      puts "📡 No account ID in webhook, will fetch from API..."
    end
    
    # Fallback: Try to get account ID from visit data via API
    visit_id = webhook_data.dig("data", "webHookEvent", "itemId")
    
    if visit_id
      Rails.logger.info "🔍 Fetching account ID from visit: #{visit_id}"
      puts "🔍 Fetching account ID from visit: #{visit_id}"
      account = find_account_by_visit_id(visit_id)
      
      if account
        Rails.logger.info "✅ Found JobberAccount via API lookup: #{account.name}"
        puts "✅ Found JobberAccount via API lookup: #{account.name}"
        return account
      end
    end
    
    # REMOVED DANGEROUS FALLBACK - No random account selection!
    Rails.logger.error "❌ No JobberAccount found for this webhook - rejecting request"
    puts "❌ No JobberAccount found for this webhook - rejecting request"
    nil
  end

  def find_account_by_visit_id(visit_id)
    # Development test mode: if visit_id is a test ID, use first account
    if Rails.env.development? && visit_id.to_s.include?('test_visit')
      Rails.logger.info "🧪 Development test mode: using first account for test visit"
      puts "🧪 Development test mode: using first account for test visit"
      return JobberAccount.first
    end
    
    # Try each account until we find one that can access this visit
    JobberAccount.find_each do |account|
      next unless account.jobber_access_token
      
      Rails.logger.info "🧪 Testing account: #{account.name}"
      puts "🧪 Testing account: #{account.name}"
      
      begin
        visit_data = JobberApiService.fetch_visit_details(visit_id, account.jobber_access_token)
        
        if visit_data && visit_data['id'] && visit_data['job'] && !visit_data['error']
          Rails.logger.info "📡 Visit successfully accessed by account: #{account.name}"
          puts "📡 Visit successfully accessed by account: #{account.name}"
          
          # This account can access the visit, so it belongs to them
          return account
        end
        
      rescue => e
        Rails.logger.info "⚠️ Account #{account.name} cannot access visit: #{e.message}"
        puts "⚠️ Account #{account.name} cannot access visit: #{e.message}"
        next
      end
    end
    
    nil
  end

  def process_jobber_data_enhanced(webhook_data, jobber_account)
    puts "Processing Jobber data with enhanced business intelligence..."
    
    # Extract visit ID from real Jobber webhook
    visit_id = webhook_data.dig("data", "webHookEvent", "itemId")
    
    if visit_id
      puts "Found visit ID: #{visit_id}"
      begin
        refreshed_account = jobber_account.refresh_jobber_access_token!
        
        if refreshed_account && refreshed_account.is_a?(JobberAccount) && refreshed_account.jobber_access_token.present?
          access_token = refreshed_account.jobber_access_token
          puts "✅ Token refreshed successfully for webhook"
        else
          puts "❌ Token refresh failed in webhook: refresh returned #{refreshed_account.inspect}"
          return generate_enhanced_fallback_data(jobber_account)
        end
      rescue => e
        puts "❌ Token refresh failed in webhook: #{e.message}"
        return generate_enhanced_fallback_data(jobber_account)
      end
      
      begin
        jobber_data = JobberApiService.fetch_visit_details(visit_id, access_token)
        
        if jobber_data && jobber_data['id'] && !jobber_data['error']
          puts "✅ Successfully fetched real Jobber data"
          return extract_enhanced_visit_data(jobber_data, jobber_account)
        else
          puts "❌ Failed to fetch Jobber data, using enhanced fallback"
          return generate_enhanced_fallback_data(jobber_account)
        end
      rescue => e
        puts "💥 Exception calling Jobber API: #{e.message}"
        return generate_enhanced_fallback_data(jobber_account)
      end
    else
      puts "No visit ID found, using enhanced test data"
      return generate_enhanced_fallback_data(jobber_account)
    end
  end

  def extract_enhanced_visit_data(jobber_data, jobber_account)
    job_data = jobber_data['job'] || {}
    client_data = job_data['client'] || {}
    property_data = job_data['property'] || {}
    address_data = property_data['address'] || {}
    notes_data = jobber_data['notes']&.dig('nodes') || []
    line_items = job_data['lineItems']&.dig('nodes') || []
    
    # Extract customer info
    company_name = client_data['companyName']
    first_name = client_data['firstName'] || "Customer"
    last_name = client_data['lastName'] || ""
    
    customer_name = if company_name.present?
                     company_name
                   else
                     "#{first_name} #{last_name}".strip
                   end
    
    # Extract email
    emails = client_data['emails'] || []
    customer_email = emails.find { |email| email['primary'] }&.dig('address') || 
                     emails.first&.dig('address') || 
                     "customer@example.com"
    
    # Extract location
    customer_location = "#{address_data['city']}, #{address_data['province']}" if address_data['city']
    customer_location ||= "Unknown location"
    
    # Extract and combine notes
    visit_notes = []
    
    # Add visit notes
    if notes_data.any?
      note_content = notes_data.map { |note| note['message'] }.join('. ')
      visit_notes << note_content if note_content.present?
    end
    
    # Add line items as context
    if line_items.any?
      line_item_content = line_items.map { |item| "#{item['name']}: #{item['description']}" }.join('. ')
      visit_notes << line_item_content if line_item_content.present?
    end
    
    combined_notes = visit_notes.join('. ').strip
    combined_notes = "Service visit completed successfully" if combined_notes.blank?
    
    {
      job_id: job_data['jobNumber'] || "SF-#{rand(1000..9999)}",
      customer_name: customer_name,
      customer_email: customer_email,
      customer_location: customer_location,
      visit_notes: combined_notes,
      visit_date: Date.current
    }
  end

  def generate_enhanced_fallback_data(jobber_account)
    # Enhanced fallback that adapts to business type
    business_profile = jobber_account.service_provider_profile
    service_type = business_profile&.main_service_type || 'General Service'
    
    # Generate service-appropriate test notes from business profile
    test_notes = if business_profile&.service_details.present?
                    "Completed service visit. #{business_profile.service_details}. All work performed according to specifications. System functioning properly."
                  else
                    "Completed service visit. All work performed according to specifications. System checked and functioning properly."
                  end
    
    {
      job_id: "SF-#{rand(1000..9999)}",
      customer_name: "Test Customer",
      customer_email: "solarharvey79@gmail.com", # Your test email
      customer_location: "Minneapolis, MN",
      visit_notes: test_notes,
      visit_date: Date.current
    }
  end

  def generate_and_send_enhanced_email(processed_data, jobber_account)
    
    # Get business profile
    business_profile = jobber_account.service_provider_profile
    
    unless business_profile
      return { 
        success: false, 
        error: 'No business profile found - please complete signup first',
        email_sent: false
      }
    end
    
    puts "✅ Using business profile: #{business_profile.company_name}"
    puts "✅ Service type: #{business_profile.main_service_type}"
    
    # Prepare visit data for new CustomerEmailService
    visit_data = {
      business_profile: business_profile,
      customer_name: processed_data[:customer_name],
      customer_email: processed_data[:customer_email],
      customer_location: processed_data[:customer_location],
      visit_notes: processed_data[:visit_notes],
      visit_date: processed_data[:visit_date]
    }
    
    # Generate AI email using new service
    email_service = CustomerEmailService.new
    generation_result = email_service.generate_visit_follow_up(visit_data)
    
    unless generation_result[:success]
      return { 
        success: false, 
        error: "Email generation failed: #{generation_result[:error]}",
        email_sent: false
      }
    end
    
    puts "✅ AI email generated successfully!"
    puts "Subject: #{generation_result[:subject]}"
    
    # Send email using existing EmailService
    send_result = EmailService.send_customer_email(
      to: processed_data[:customer_email],
      subject: generation_result[:subject],
      content: generation_result[:email_content],
      from_name: business_profile.company_name
    )
    
    if send_result[:success]
      puts "✅ Email sent successfully!"
      puts "   Provider: #{send_result[:provider]}"
      puts "   Email ID: #{send_result[:email_id]}"
      
      {
        success: true,
        email_sent: true,
        subject: generation_result[:subject],
        email_content: generation_result[:email_content],
        email_id: send_result[:email_id],
        customer_email: processed_data[:customer_email]
      }
    else
      puts "❌ Email sending failed: #{send_result[:error]}"
      
      {
        success: true, # AI generation succeeded
        email_sent: false,
        subject: generation_result[:subject],
        email_content: generation_result[:email_content],
        send_error: send_result[:error]
      }
    end
  end

  # Keep your existing helper methods for backward compatibility
  def get_access_token_for_account
    account = JobberAccount.first
    account&.get_valid_access_token
  end
end