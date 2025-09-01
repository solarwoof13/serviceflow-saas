# app/services/email_safety_service.rb
class EmailSafetyService
  
  def self.safe_to_send_email?(visit_id:, customer_email:, webhook_data:)
    new.safe_to_send_email?(
      visit_id: visit_id,
      customer_email: customer_email, 
      webhook_data: webhook_data
    )
  end
  
  def safe_to_send_email?(visit_id:, customer_email:, webhook_data:)
    # Check 1: Already sent email for this visit?
    if EmailDeduplicationLog.already_sent_for_visit?(visit_id, customer_email)
      log_blocked_email(visit_id, customer_email, webhook_data, 'duplicate_visit')
      return { safe: false, reason: 'Email already sent for this visit in last 24 hours' }
    end
    
    # Check 2: Is this a valid webhook topic for emails?
    webhook_topic = webhook_data.dig("data", "webHookEvent", "topic")
    
    unless valid_email_trigger?(webhook_topic)
      log_blocked_email(visit_id, customer_email, webhook_data, 'invalid_topic')
      return { safe: false, reason: "Webhook topic '#{webhook_topic}' should not trigger customer emails" }
    end
    
    # Check 3: Rate limiting - max 3 emails per customer per hour
    recent_emails = EmailDeduplicationLog
      .where(customer_email: customer_email)
      .where('created_at > ?', 1.hour.ago)
      .count
      
    if recent_emails >= 3
      log_blocked_email(visit_id, customer_email, webhook_data, 'rate_limit')
      return { safe: false, reason: 'Rate limit exceeded - max 3 emails per hour per customer' }
    end
    
    # Check 4: Is this a test/development webhook?
    if development_test_webhook?(webhook_data)
      Rails.logger.info "🧪 Development test webhook detected - allowing but flagging"
      return { safe: true, reason: 'development_test' }
    end
    
    # All checks passed
    { safe: true, reason: 'all_checks_passed' }
  end
  
  private
  
  def valid_email_trigger?(webhook_topic)
    # Only these webhook topics should trigger customer emails
    email_worthy_topics = [
      'VISIT_COMPLETE',     # ✅ Original format
      'VISIT_COMPLETED',    # ✅ FIXED: Add the variant with 'D' 
      'JOB_COMPLETE',       # ✅ Job completion
      'JOB_COMPLETED'       # ✅ Job completion variant
    ]
    
    # These should NOT trigger emails (prevents previous n8n spam scenario)
    spam_topics = [
      'JOB_UPDATE',         # ❌ Moving jobs, status changes
      'JOB_CREATE',         # ❌ Job creation
      'CLIENT_UPDATE',      # ❌ Archiving customers - this was your n8n problem!
      'CLIENT_CREATE',      # ❌ New customers
      'CLIENT_DESTROY',     # ❌ Customer deletion
      'VISIT_CREATE',       # ❌ Scheduled visits  
      'VISIT_UPDATE',       # ❌ Visit edits (not completion)
      'VISIT_EDIT',         # ❌ Visit modifications
      'VISIT_RESCHEDULE',   # ❌ Date/time changes
      'VISIT_DELETE',       # ❌ Visit cancellations
      'PROPERTY_UPDATE',    # ❌ Address changes
      'INVOICE_UPDATE',     # ❌ Invoice edits
      'INVOICE_CREATE',     # ❌ Invoice generation
      'QUOTE_UPDATE',       # ❌ Quote modifications
      'USER_UPDATE'         # ❌ Staff changes
    ]
    
    return false if spam_topics.include?(webhook_topic)
    return true if email_worthy_topics.include?(webhook_topic)
    
    # Unknown topic - be conservative and block
    Rails.logger.warn "⚠️  Unknown webhook topic: #{webhook_topic} - blocking email"
    false
  end
  
  def development_test_webhook?(webhook_data)
    # Check for development indicators
    visit_id = webhook_data.dig("data", "webHookEvent", "itemId")
    account_id = webhook_data.dig("data", "webHookEvent", "accountId")
    
    # Common test patterns
    test_indicators = [
      visit_id&.include?('test'),
      visit_id&.include?('dev'),
      visit_id&.include?('mock'),
      account_id&.include?('test'),
      Rails.env.development?,
      webhook_data.to_s.include?('sandbox')
    ]
    
    test_indicators.any?
  end
  
  def log_blocked_email(visit_id, customer_email, webhook_data, block_reason)
    webhook_topic = webhook_data.dig("data", "webHookEvent", "topic")
    job_id = extract_job_id_from_webhook(webhook_data)
    
    EmailDeduplicationLog.log_email_attempt(
      visit_id: visit_id,
      job_id: job_id,
      customer_email: customer_email,
      webhook_topic: webhook_topic,
      webhook_data: webhook_data,
      email_status: 'duplicate_blocked',  # FIXED: Use correct column name
      block_reason: block_reason
    )
    
    Rails.logger.warn "🚫 Email blocked for visit #{visit_id}: #{block_reason}"
    puts "🚫 Email blocked for visit #{visit_id}: #{block_reason}"
  end
  
  def extract_job_id_from_webhook(webhook_data)
    webhook_data.dig("data", "job", "id") || 
    webhook_data.dig("data", "webHookEvent", "jobId") ||
    webhook_data.dig("job", "id") ||  # ADDED: Check the job data in your webhook format
    "unknown"
  end
end