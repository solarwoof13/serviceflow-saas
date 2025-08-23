# Create file: app/controllers/api/v1/customer_emails_controller.rb
class Api::V1::CustomerEmailsController < ApplicationController
  skip_before_action :validate_session
  
  def generate_and_send
    # Get business profile
    business_profile = get_business_profile
    
    unless business_profile
      render json: { error: 'Business profile not found' }, status: :not_found
      return
    end
    
    # Build visit data
    visit_data = {
      business_profile: business_profile,
      customer_name: params[:customer_name],
      customer_email: params[:customer_email],
      customer_location: params[:customer_location],
      visit_notes: params[:visit_notes],
      visit_date: parse_visit_date(params[:visit_date])
    }
    
    # Validate required fields
    validation_errors = validate_visit_data(visit_data)
    if validation_errors.any?
      render json: { error: 'Validation failed', details: validation_errors }, status: :bad_request
      return
    end
    
    # Generate AI email
    email_service = CustomerEmailService.new
    generation_result = email_service.generate_visit_follow_up(visit_data)
    
    response_data = {
      success: generation_result[:success],
      email_content: generation_result[:email_content],
      subject: generation_result[:subject],
      customer_name: visit_data[:customer_name],
      visit_date: visit_data[:visit_date].strftime('%B %d, %Y'),
      generated_at: generation_result[:generated_at],
      ai_generated: generation_result[:success]
    }
    
    # Send email if requested and email provided
    if params[:send_email] == 'true' && visit_data[:customer_email].present?
      send_result = EmailService.send_customer_email(
        to: visit_data[:customer_email],
        subject: generation_result[:subject],
        content: generation_result[:email_content],
        from_name: business_profile.company_name
      )
      
      response_data.merge!(
        email_sent: send_result[:success],
        email_status: send_result,
        email_id: send_result[:email_id]
      )
    else
      response_data[:email_sent] = false
    end
    
    render json: response_data, status: :ok
    
  rescue => e
    Rails.logger.error "Customer email controller error: #{e.message}"
    Rails.logger.error e.backtrace[0..5].join("\n")
    
    render json: {
      error: 'Email generation service temporarily unavailable',
      details: e.message
    }, status: :internal_server_error
  end
  
  def preview
    business_profile = get_business_profile
    
    render json: {
      service_available: true,
      business_profile_found: business_profile.present?,
      company_name: business_profile&.company_name,
      service_type: business_profile&.main_service_type,
      grok_configured: ENV['GROK_API_KEY'].present?,
      email_configured: ENV['SENDGRID_API_KEY'].present?
    }
  end
  
  private
  
  def get_business_profile
    # For testing, get the profile from test account
    # In production, this would come from authenticated user
    JobberAccount.find_by(jobber_id: 'test_user_signup')&.service_provider_profile
  end
  
  def parse_visit_date(date_param)
    return Date.current if date_param.blank?
    
    begin
      Date.parse(date_param)
    rescue ArgumentError
      Date.current
    end
  end
  
  def validate_visit_data(visit_data)
    errors = []
    
    errors << 'Customer name is required' if visit_data[:customer_name].blank?
    errors << 'Visit notes are required' if visit_data[:visit_notes].blank?
    errors << 'Customer location is required' if visit_data[:customer_location].blank?
    
    if params[:send_email] == 'true'
      errors << 'Customer email is required to send email' if visit_data[:customer_email].blank?
      
      if visit_data[:customer_email].present? && !valid_email?(visit_data[:customer_email])
        errors << 'Invalid email format'
      end
    end
    
    errors
  end
  
  def valid_email?(email)
    email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end
end