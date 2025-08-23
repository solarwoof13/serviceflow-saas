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
      render json: result, status: :ok
    end
    
  rescue => e
    Rails.logger.error "AI Enhancement controller error: #{e.message}"
    render json: { error: 'Enhancement service temporarily unavailable' }, status: :internal_server_error
  end
end