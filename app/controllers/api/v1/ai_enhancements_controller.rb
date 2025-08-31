class Api::V1::AiEnhancementsController < ApplicationController
  skip_before_action :validate_session
  
  def enhance
    text = params[:text]
    enhancement_type = params[:enhancement_type]
    context = params[:context] || {}
    
    Rails.logger.info "Enhancement Request:"
    Rails.logger.info "  Text: #{text}"
    Rails.logger.info "  Type: #{enhancement_type}"
    Rails.logger.info "  Context: #{context}"
    
    # Validation
    if text.blank?
      render json: { error: 'Text is required' }, status: :bad_request
      return
    end
    
    if enhancement_type.blank?
      render json: { error: 'Enhancement type is required' }, status: :bad_request
      return
    end
    
    if text.length > 500
      render json: { error: 'Text too long (max 500 characters)' }, status: :bad_request
      return
    end
    
    # Use existing AiService
    prompt = build_enhancement_prompt(text, enhancement_type, context)
    result = AiService.generate_customer_email(prompt)
    
    if result[:success] && result[:email_content]
      suggestions = [result[:email_content]]
      render json: { suggestions: suggestions }, status: :ok
    else
      render json: { error: result[:error] || 'Enhancement failed' }, status: :internal_server_error
    end
    
  rescue => e
    Rails.logger.error "AI Enhancement controller error: #{e.message}"
    render json: { error: 'Enhancement service temporarily unavailable' }, status: :internal_server_error
  end

  private

  def build_enhancement_prompt(text, enhancement_type, context)
    "Improve this #{enhancement_type.humanize.downcase}: #{text}"
  end
end