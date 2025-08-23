# Create file: app/controllers/api/v1/jobber_webhooks_controller.rb
class Api::V1::JobberWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :validate_session
  
  def visit_completed
    Rails.logger.info "🎯 Jobber webhook received: visit_completed"
    Rails.logger.info "📡 Webhook payload: #{params.to_unsafe_h}"
    
    # Extract webhook data
    webhook_data = extract_webhook_data(params)
    
    unless webhook_data[:valid]
      Rails.logger.error "❌ Invalid webhook data: #{webhook_data[:error]}"
      render json: { error: webhook_data[:error] }, status: :bad_request
      return
    end
    
    # Get the JobberAccount for this webhook
    jobber_account = find_jobber_account(webhook_data)
    
    unless jobber_account
      Rails.logger.error "❌ No JobberAccount found for this webhook"
      render json: { error: 'Account not found' }, status: :not_found
      return
    end
    
    # Process the visit completion
    result = process_visit_completion(webhook_data, jobber_account)
    
    if result[:success]
      Rails.logger.info "✅ Visit completion processed successfully"
      render json: { success: true, message: result[:message] }, status: :ok
    else
      Rails.logger.error "❌ Failed to process visit completion: #{result[:error]}"
      render json: { success: false, error: result[:error] }, status: :internal_server_error
    end
    
  rescue => e
    Rails.logger.error "💥 Webhook processing error: #{e.message}"
    Rails.logger.error e.backtrace[0..5].join("\n")
    render json: { error: 'Webhook processing failed' }, status: :internal_server_error
  end
  
  # Health check endpoint for webhook testing
  def health
    render json: { 
      status: 'healthy', 
      timestamp: Time.current,
      service: 'ServiceFlow Webhook Handler'
    }
  end
  
  private
  
  def extract_webhook_data(params)
    # Jobber webhook structure - adjust based on actual webhook format
    if params[:data] && params[:data][:visit]
      visit_data = params[:data][:visit]
      {
        valid: true,
        visit_id: visit_data[:id],
        account_id: params[:account_id] || params[:data][:account][:id],
        event_type: params[:event_type] || 'visit.completed'
      }
    elsif params[:visit_id] # Alternative webhook format
      {
        valid: true,
        visit_id: params[:visit_id],
        account_id: params[:account_id],
        event_type: params[:event_type] || 'visit.completed'
      }
    else
      {
        valid: false,
        error: 'Missing required webhook data (visit_id, account_id)'
      }
    end
  end
  
  def find_jobber_account(webhook_data)
    # Try to find by Jobber account ID first
    account = JobberAccount.find_by(account_id: webhook_data[:account_id])
    
    # Fallback: try to find by any other identifying information
    account ||= JobberAccount.first if Rails.env.development? # Dev fallback
    
    if account
      Rails.logger.info "✅ Found JobberAccount: #{account.name} (ID: #{account.id})"
    else
      Rails.logger.error "❌ No JobberAccount found for account_id: #{webhook_data[:account_id]}"
    end
    
    account
  end
  
  def process_visit_completion(webhook_data, jobber_account)
    visit_id = webhook_data[:visit_id]
    access_token = jobber_account.jobber_access_token
    
    unless access_token
      return { success: false, error: 'No access token available for this account' }
    end
    
    # Fetch detailed visit information from Jobber
    Rails.logger.info "📡 Fetching visit details from Jobber API..."
    visit_details = JobberApiService.fetch_visit_details(visit_id, access_token)
    
    if visit_details[:error]
      return { success: false, error: "Failed to fetch visit details: #{visit_details[:error]}" }
    end
    
    # Extract customer and visit information
    customer_data = extract_customer_data(visit_details)
    
    unless customer_data[:valid]
      return { success: false, error: customer_data[:error] }
    end
    
    # Generate and send AI email
    email_result = generate_and_send_email(customer_data, jobber_account)
    
    if email_result[:success]
      # Log the successful email generation
      Rails.logger.info "📧 AI email sent successfully to #{customer_data[:customer_email]}"
      Rails.logger.info "📧 Email subject: #{email_result[:subject]}"
      
      {
        success: true,
        message: "AI follow-up email sent to #{customer_data[:customer_name]}",
        email_sent: true,
        subject: email_result[:subject]
      }
    else
      {
        success: false,
        error: "Email generation failed: #{email_result[:error]}"
      }
    end
  end
  
  def extract_customer_data(visit_details)
    begin
      job = visit_details['job']
      client = job['client']
      property = job['property']
      
      # Get primary email
      primary_email = nil
      if client['emails'] && client['emails'].any?
        primary_email_obj = client['emails'].find { |e| e['primary'] } || client['emails'].first
        primary_email = primary_email_obj['address'] if primary_email_obj
      end
      
      # Get customer name
      customer_name = if client['companyName'].present?
                       client['companyName']
                     else
                       "#{client['firstName']} #{client['lastName']}".strip
                     end
      
      # Get location
      address = property['address']
      location = "#{address['city']}, #{address['province']}" if address
      
      # Get visit notes
      visit_notes = extract_visit_notes(visit_details)
      
      # Validation
      if customer_name.blank?
        return { valid: false, error: 'Customer name not found' }
      end
      
      if primary_email.blank?
        return { valid: false, error: 'Customer email not found' }
      end
      
      if visit_notes.blank?
        return { valid: false, error: 'Visit notes not found' }
      end
      
      {
        valid: true,
        customer_name: customer_name,
        customer_email: primary_email,
        customer_location: location || 'Unknown location',
        visit_notes: visit_notes,
        visit_date: Date.current,
        job_number: job['jobNumber']
      }
      
    rescue => e
      Rails.logger.error "❌ Error extracting customer data: #{e.message}"
      { valid: false, error: "Data extraction failed: #{e.message}" }
    end
  end
  
  def extract_visit_notes(visit_details)
    notes = []
    
    # Get visit notes
    if visit_details['notes'] && visit_details['notes']['nodes']
      visit_notes = visit_details['notes']['nodes'].map { |note| note['message'] }.join('. ')
      notes << visit_notes if visit_notes.present?
    end
    
    # Get line items as context
    if visit_details['job']['lineItems'] && visit_details['job']['lineItems']['nodes']
      line_items = visit_details['job']['lineItems']['nodes']
                     .map { |item| "#{item['name']}: #{item['description']}" }
                     .join('. ')
      notes << line_items if line_items.present?
    end
    
    combined_notes = notes.join('. ').strip
    
    # Fallback if no notes
    if combined_notes.blank?
      "Service visit completed on #{Date.current.strftime('%B %d, %Y')}"
    else
      combined_notes
    end
  end
  
  def generate_and_send_email(customer_data, jobber_account)
    # Get business profile
    business_profile = jobber_account.service_provider_profile
    
    unless business_profile
      return { success: false, error: 'No business profile found for this account' }
    end
    
    # Prepare visit data for email generation
    visit_data = {
      business_profile: business_profile,
      customer_name: customer_data[:customer_name],
      customer_email: customer_data[:customer_email],
      customer_location: customer_data[:customer_location],
      visit_notes: customer_data[:visit_notes],
      visit_date: customer_data[:visit_date]
    }
    
    # Generate AI email
    email_service = CustomerEmailService.new
    generation_result = email_service.generate_visit_follow_up(visit_data)
    
    unless generation_result[:success]
      return { 
        success: false, 
        error: "Email generation failed: #{generation_result[:error]}" 
      }
    end
    
    # Send email
    send_result = EmailService.send_customer_email(
      to: customer_data[:customer_email],
      subject: generation_result[:subject],
      content: generation_result[:email_content],
      from_name: business_profile.company_name
    )
    
    if send_result[:success]
      {
        success: true,
        subject: generation_result[:subject],
        email_id: send_result[:email_id],
        customer_email: customer_data[:customer_email]
      }
    else
      {
        success: false,
        error: "Email sending failed: #{send_result[:error]}"
      }
    end
  end
end