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

     # CHECK FOR DUPLICATES
    if jobber_account.processed_visit_ids.include?(visit_id)
      Rails.logger.info "⚠️ Duplicate webhook for visit #{visit_id} - skipping"
      return render json: { status: 'duplicate', message: 'Visit already processed' }, status: :ok
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

      # AFTER SUCCESSFUL PROCESSING, MARK AS PROCESSED
      if email_result[:success] && email_result[:email_sent]
        jobber_account.processed_visit_ids ||= []
        jobber_account.processed_visit_ids << visit_id
        jobber_account.save
        Rails.logger.info "✅ Marked visit #{visit_id} as processed"
      end

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
      account = JobberAccount.find_or_merge_by_jobber_id(webhook_account_id)
      
      if account
        Rails.logger.info "✅ Found JobberAccount: #{account.name}"
        return account
      else
        Rails.logger.warn "⚠️ No JobberAccount found for jobber_id: #{webhook_account_id}"
      end
    else
      Rails.logger.info "📡 No account ID in webhook, will fetch from API..."
    end
    
    # Fallback: Try to get account ID from visit data via API
    visit_id = webhook_data.dig("data", "webHookEvent", "itemId")
    
    if visit_id
      Rails.logger.info "🔍 Fetching account ID from visit: #{visit_id}"
      account = find_account_by_visit_id(visit_id)
      
      if account
        Rails.logger.info "✅ Found JobberAccount via API lookup: #{account.name}"
        return account
      end
    end
    
    # REMOVED DANGEROUS FALLBACK - No random account selection!
    Rails.logger.error "❌ No JobberAccount found for this webhook - rejecting request"
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
    # Extract visit ID from real Jobber webhook
    visit_id = webhook_data.dig("data", "webHookEvent", "itemId")
    
    unless visit_id
      Rails.logger.info "No visit ID found in webhook"
      return generate_enhanced_fallback_data(jobber_account)
    end
    
    # Handle token refresh with graceful error handling
    begin
      refreshed_account = jobber_account.refresh_jobber_access_token!
      
      unless refreshed_account && refreshed_account.jobber_access_token.present?
        Rails.logger.warn "Token refresh failed for #{jobber_account.name} - using fallback"
        jobber_account.update!(needs_reauthorization: true)
        return generate_enhanced_fallback_data(jobber_account)
      end
      
      access_token = refreshed_account.jobber_access_token
    rescue => e
      Rails.logger.error "Token refresh error for #{jobber_account.name}: #{e.message}"
      if e.message.include?("Unauthorized")
        jobber_account.update!(needs_reauthorization: true)
      end
      return generate_enhanced_fallback_data(jobber_account)
    end
    
    # Fetch visit data from Jobber API
    begin
      jobber_data = JobberApiService.fetch_visit_details(visit_id, access_token)
      
      if jobber_data && jobber_data['id'] && !jobber_data['error']
        Rails.logger.info "Successfully fetched Jobber data for visit #{visit_id}"
        return extract_enhanced_visit_data(jobber_data, jobber_account)
      else
        Rails.logger.warn "Failed to fetch Jobber data for visit #{visit_id} - using fallback"
        return generate_enhanced_fallback_data(jobber_account)
      end
    rescue => e
      Rails.logger.error "Exception calling Jobber API for visit #{visit_id}: #{e.message}"
      return generate_enhanced_fallback_data(jobber_account)
    end
  end

  def extract_enhanced_visit_data(jobber_data, jobber_account)
    job_data = jobber_data['job'] || {}
    client_data = job_data['client'] || {}
    property_data = job_data['property'] || {}
    address_data = property_data['address'] || {}
    line_items = job_data['lineItems']&.dig('nodes') || []
    
    # GET VISIT COMPLETION TIME (or use current time)
    visit_completed_at = jobber_data['completedAt'] || jobber_data['endAt']
    reference_time = if visit_completed_at
                      DateTime.parse(visit_completed_at)
                    else
                      DateTime.current
                    end
    
    # GET THE VISIT DATE (just the date, not time)
    visit_date = reference_time.to_date
    
    Rails.logger.info "🕐 Using visit date for filtering: #{visit_date}"
    puts "DEBUG: Visit date: #{visit_date}"
    
    # ADD TECHNICIAN INFO
    technician_data = jobber_data.dig('assignedUsers', 'nodes', 0) || {}
    technician_name = if technician_data['name'].present?
                        if technician_data['name'].is_a?(Hash)
                          "#{technician_data['name']['firstName']} #{technician_data['name']['lastName']}".strip
                        else
                          technician_data['name']
                        end
                      else
                        'Your Service Team'
                      end
    
    # GET ALL NOTES
    all_notes = jobber_data.dig('notes', 'nodes') || []
    
    Rails.logger.info "📝 Total notes found: #{all_notes.length}"
    puts "DEBUG: Total notes: #{all_notes.length}"
    
    # SAME-DAY FILTER (work day approach)
    same_day_notes = []
    older_notes = []
    
    all_notes.each do |note|
      begin
        note_datetime = DateTime.parse(note['createdAt'])
        note_date = note_datetime.to_date
        note_message = note['message'] || note['content'] || ""
        
        # Calculate days difference
        days_diff = (visit_date - note_date).to_i.abs
        
        Rails.logger.info "📝 Note from #{note_date} (#{days_diff} days from visit): #{note_message.first(50)}..."
        puts "DEBUG: Note date: #{note_date}, Days difference: #{days_diff}"
        
        # WORK DAY FILTER: Same day = current work day
        if days_diff == 0
          same_day_notes << {
            message: note_message,
            created_at: note_datetime,
            days_diff: days_diff
          }
          Rails.logger.info "✅ SAME DAY note (work day) - INCLUDED"
          puts "DEBUG: ✅ INCLUDED - same work day"
        else
          older_notes << {
            message: note_message,
            created_at: note_datetime,
            days_diff: days_diff
          }
          Rails.logger.info "📚 DIFFERENT DAY note (#{days_diff} days ago) - EXCLUDED"
          puts "DEBUG: 📚 EXCLUDED - #{days_diff} days ago"
        end
        
      rescue => e
        Rails.logger.error "⚠️ Could not parse note date: #{note['createdAt']} - #{e.message}"
        puts "DEBUG: Could not parse note date: #{note['createdAt']}"
        # Skip notes with bad dates
      end
    end
    
    Rails.logger.info "📊 Same-day filtering results: #{same_day_notes.length} same-day notes, #{older_notes.length} older notes"
    puts "DEBUG: Final count - Same Day: #{same_day_notes.length}, Older: #{older_notes.length}"
    
    # Extract customer info (unchanged)
    company_name = client_data['companyName']
    first_name = client_data['firstName'] || "Customer"
    last_name = client_data['lastName'] || ""
    
    customer_name = if company_name.present?
                      company_name
                    else
                      "#{first_name} #{last_name}".strip
                    end
    
    # Extract email (unchanged)
    emails = client_data['emails'] || []
    customer_email = emails.find { |email| email['primary'] }&.dig('address') || 
                    emails.first&.dig('address') || 
                    "customer@example.com"
    
    # Extract location (unchanged)
    customer_location = "#{address_data['city']}, #{address_data['province']}" if address_data['city']
    customer_location ||= "Unknown location"
    
    # Format SAME DAY notes (current work day)
    current_notes_text = same_day_notes.map { |note| note[:message] }.join('. ').strip
    
    # If no same-day notes, use line items or fallback
    if current_notes_text.blank?
      if line_items.any?
        line_item_content = line_items.map do |item| 
          description = item['description'].present? ? ": #{item['description']}" : ""
          "#{item['name']}#{description}"
        end.join(', ')
        current_notes_text = "Completed scheduled services: #{line_item_content}"
      else
        current_notes_text = "Completed scheduled service visit successfully"
      end
      
      Rails.logger.info "📝 No same-day notes found - using fallback: #{current_notes_text}"
      puts "DEBUG: Using fallback content"
    end
    
    # Format historical notes (older than same day) - limit to last 7 days for context
    recent_older_notes = older_notes.select { |note| note[:days_diff] <= 7 } # Last 7 days only
    historical_notes_text = recent_older_notes.map do |note|
      "#{note[:message]} (#{note[:days_diff]} days ago)"
    end.join('. ').strip
    
    Rails.logger.info "📄 Same-day notes: #{current_notes_text.first(100)}..."
    Rails.logger.info "📚 Historical context (7d): #{historical_notes_text.first(100)}..." if historical_notes_text.present?
    
    puts "DEBUG: Final same-day notes: #{current_notes_text.first(100)}..."
    puts "DEBUG: Final historical notes: #{historical_notes_text.first(100)}..." if historical_notes_text.present?
    
    # RETURN DATA with same-day filtered notes
    {
      job_id: job_data['jobNumber'] || "SF-#{rand(1000..9999)}",
      customer_name: customer_name,
      customer_email: customer_email,
      customer_location: customer_location,
      
      # SAME-DAY FILTERED NOTES
      current_visit_notes: current_notes_text,
      historical_notes: historical_notes_text,
      
      # LEGACY - for backwards compatibility
      visit_notes: current_notes_text,
      
      visit_date: reference_time,
      technician_name: technician_name,
      customer_signature: nil,
      
      # METADATA for debugging
      notes_metadata: {
        total_notes: all_notes.length,
        same_day_notes: same_day_notes.length,
        older_notes: older_notes.length,
        visit_date: visit_date.iso8601,
        filtering_method: "same_day_work_day"
      }
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
      
      # SEPARATED NOTES for consistency
      current_visit_notes: test_notes,
      historical_notes: "",
      
      # LEGACY
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
    
    # Prepare visit data with SEPARATED NOTES
    visit_data = {
      business_profile: business_profile,
      customer_name: processed_data[:customer_name],
      customer_email: processed_data[:customer_email],
      customer_location: processed_data[:customer_location],
      
      # UPDATED: Use separated notes
      current_visit_notes: processed_data[:current_visit_notes],
      historical_notes: processed_data[:historical_notes],
      
      # LEGACY: Keep for backwards compatibility  
      visit_notes: processed_data[:visit_notes] || processed_data[:current_visit_notes],
      
      visit_date: processed_data[:visit_date],
      technician_name: processed_data[:technician_name],
      customer_signature: processed_data[:customer_signature]
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
    
    # Send email using existing EmailService
    send_result = EmailService.send_customer_email(
      to: processed_data[:customer_email],
      subject: generation_result[:subject],
      content: generation_result[:email_content],
      from_name: business_profile.company_name
    )
    
    if send_result[:success]
      {
        success: true,
        email_sent: true,
        subject: generation_result[:subject],
        email_content: generation_result[:email_content],
        email_id: send_result[:email_id],
        customer_email: processed_data[:customer_email]
      }
    else
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