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
    notes_data = jobber_data['notes']&.dig('nodes') || []
    line_items = job_data['lineItems']&.dig('nodes') || []
    
    # ADD TECHNICIAN INFO
    technician_data = jobber_data.dig('assignedUsers', 'nodes', 0) || {}
    technician_name = if technician_data['name'].present?
                        # Extract first and last name if full name object
                        if technician_data['name'].is_a?(Hash)
                          "#{technician_data['name']['firstName']} #{technician_data['name']['lastName']}".strip
                        else
                          technician_data['name']
                        end
                      else
                        'Your Service Team'
                      end
    
    # ADD SIGNATURE DATA (if available)
    signature_data = jobber_data.dig('signature') || {}
    customer_signature = signature_data['signature'] || nil
    
    # Get visit completion date for filtering
    visit_completed_at = jobber_data.dig('completedAt') || jobber_data.dig('endAt')
    
    # ENHANCED NOTE FILTERING: Separate current visit notes from historical notes
    current_visit_notes = []
    historical_notes = []
    
    if visit_completed_at
      visit_datetime = DateTime.parse(visit_completed_at) rescue nil
      if visit_datetime
        Rails.logger.info "🕐 Visit completed at: #{visit_datetime}"
        puts "DEBUG: Visit completed at: #{visit_datetime}"
        
        # Separate notes based on proximity to visit completion time
        notes_data.each do |note|
          note_datetime = DateTime.parse(note['createdAt']) rescue nil
          next unless note_datetime
          
          time_diff_hours = ((note_datetime - visit_datetime).abs * 24).round(2)
          note_message = note['message'] || note['content'] || ""
          
          Rails.logger.info "📝 Note from #{note_datetime} (#{time_diff_hours}h from visit): #{note_message.first(50)}..."
          puts "DEBUG: Note time diff: #{time_diff_hours} hours - #{note_message.first(50)}..."
          
          # Notes within 3 hours of visit completion are "current visit"
          if time_diff_hours <= 3.0
            current_visit_notes << {
              message: note_message,
              created_at: note_datetime,
              time_diff: time_diff_hours
            }
            Rails.logger.info "✅ CURRENT visit note (#{time_diff_hours}h)"
            puts "DEBUG: ✅ CURRENT visit note"
          else
            historical_notes << {
              message: note_message,
              created_at: note_datetime,
              time_diff: time_diff_hours
            }
            Rails.logger.info "📚 Historical note (#{time_diff_hours}h)"
            puts "DEBUG: 📚 Historical note"
          end
        end
      else
        Rails.logger.warn "⚠️ Could not parse visit completion date: #{visit_completed_at}"
        puts "DEBUG: Could not parse visit completion date"
        # If we can't parse visit date, treat all notes as current (safer)
        notes_data.each do |note|
          current_visit_notes << {
            message: note['message'] || note['content'] || "",
            created_at: nil,
            time_diff: 0
          }
        end
      end
    else
      Rails.logger.info "📝 No visit completion time - using all notes as current visit"
      puts "DEBUG: No visit completion time - using all notes as current"
      # No completion time, treat all notes as current
      notes_data.each do |note|
        current_visit_notes << {
          message: note['message'] || note['content'] || "",
          created_at: nil,
          time_diff: 0
        }
      end
    end
    
    Rails.logger.info "📊 Note filtering results: #{current_visit_notes.length} current, #{historical_notes.length} historical"
    puts "DEBUG: Final count - Current: #{current_visit_notes.length}, Historical: #{historical_notes.length}"
    
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
    
    # Format CURRENT VISIT notes (primary content for email)
    current_notes_text = current_visit_notes.map { |note| note[:message] }.join('. ').strip
    
    # Format HISTORICAL notes (context only)
    historical_notes_text = historical_notes.map do |note|
      date_str = note[:created_at] ? note[:created_at].strftime('%m/%d/%Y') : 'Previous visit'
      "#{note[:message]} (#{date_str})"
    end.join('. ').strip
    
    # Add line items to current visit context if no notes
    if current_notes_text.blank? && line_items.any?
      line_item_content = line_items.map { |item| 
        description = item['description'].present? ? ": #{item['description']}" : ""
        "#{item['name']}#{description}"
      }.join(', ')
      current_notes_text = "Completed service: #{line_item_content}"
    end
    
    # Ensure we have some content
    current_notes_text = "Service visit completed successfully" if current_notes_text.blank?
    
    Rails.logger.info "📄 Current visit content: #{current_notes_text.first(100)}..."
    Rails.logger.info "📚 Historical content: #{historical_notes_text.first(100)}..." if historical_notes_text.present?
    
    puts "DEBUG: Current notes: #{current_notes_text.first(100)}..."
    puts "DEBUG: Historical notes: #{historical_notes_text.first(100)}..." if historical_notes_text.present?
    
    # RETURN ENHANCED DATA with separated notes
    {
      job_id: job_data['jobNumber'] || "SF-#{rand(1000..9999)}",
      customer_name: customer_name,
      customer_email: customer_email,
      customer_location: customer_location,
      
      # SEPARATED NOTES - Primary change for email focus
      current_visit_notes: current_notes_text,
      historical_notes: historical_notes_text,
      
      # LEGACY - for backwards compatibility
      visit_notes: current_notes_text,
      
      visit_date: visit_completed_at || Date.current,
      technician_name: technician_name,
      customer_signature: customer_signature,
      
      # METADATA for debugging
      notes_metadata: {
        total_notes: notes_data.length,
        current_count: current_visit_notes.length,
        historical_count: historical_notes.length,
        visit_completion_time: visit_completed_at
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
    
    # PLACE THE FIX HERE - Replace the hardcoded email:
    customer_email = if Rails.env.development?
                      "solarharvey79@gmail.com" # Test email for development
                    else
                      "noreply@serviceflow.com" # Safe fallback for production
                    end
    
    {
      job_id: "SF-#{rand(1000..9999)}",
      customer_name: "Test Customer",
      customer_email: customer_email, # Use the conditional email here
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