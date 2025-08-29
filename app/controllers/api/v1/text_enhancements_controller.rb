class Api::V1::TextEnhancementsController < ApplicationController
  skip_before_action :validate_session
  
  def create
    profile_params = params.require(:service_provider_profile).permit(
      :company_name, :company_description, :main_service_type, 
      :service_details, :unique_selling_points, :email_tone
    )
    
    enhanced_text = generate_enhanced_description(profile_params)
    
    render json: { enhanced_text: enhanced_text }
  end
  
  private
  
  def generate_enhanced_description(params)
    business_type = params[:main_service_type]&.downcase || ""
    
    if business_type.include?('beekeep')
      "We are a professional beekeeping business specializing in sustainable hive management for homes and businesses. We practice treatment-free methods using mite-resistant genetics to help bees express their natural ability to manage varroa mites. We utilize selective breeding to identify high-performing colonies and use those genetics to improve hive resilience across our apiaries."
    else
      "We are a professional #{params[:main_service_type]} business dedicated to providing exceptional service to our clients. Our experienced team uses industry best practices and modern techniques to deliver reliable, high-quality results."
    end
  end
end