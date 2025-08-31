class Api::V1::AiEnhancementsController < ApplicationController
  skip_before_action :validate_session
  
  def enhance
    text = params[:text]
    enhancement_type = params[:enhancement_type]
    context = params[:context] || {}
    
    # Validation
    if text.blank?
      render json: { error: 'Text is required' }, status: :bad_request
      return
    end
    
    if enhancement_type.blank?
      render json: { error: 'Enhancement type is required' }, status: :bad_request
      return
    end
    
    # Security check - limit text length
    if text.length > 500
      render json: { error: 'Text too long (max 500 characters)' }, status: :bad_request
      return
    end
    
    service = AiEnhancementService.new
    result = service.enhance_text(text, enhancement_type, context)
    
    if result[:error]
      render json: result, status: :internal_server_error
    else
      # Save the enhanced text to create/update business profile
      save_enhanced_business_profile(result, context)
      
      render json: result, status: :ok
    end
    
  rescue => e
    Rails.logger.error "AI Enhancement controller error: #{e.message}"
    render json: { error: 'Enhancement service temporarily unavailable' }, status: :internal_server_error
  end
  
  private

  def save_enhanced_business_profile(result, context)
    # Find existing profile - adjust this based on how you identify the account
    # Option 1: If you have a current_user with jobber_account
    profile = current_user&.jobber_account&.service_provider_profile
    
    # Option 2: If using session-based account
    # profile = ServiceProviderProfile.find_by(jobber_account_id: session[:jobber_account_id])
    
    # Option 3: If context has a different identifier
    # profile = ServiceProviderProfile.find_by(jobber_account_id: context[:account_id])
    
    return unless profile # Skip if no profile found
    
    # Update the appropriate field based on enhancement type
    case enhancement_type
    when 'company_description'
      profile.update(company_description: result[:suggestions].first)
    when 'service_details'
      profile.update(service_details: result[:suggestions].first)
    when 'unique_selling_points'
      profile.update(unique_selling_points: result[:suggestions].first)
    when 'local_expertise'
      profile.update(local_expertise: result[:suggestions].first)
    end
  end
end