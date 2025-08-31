class Api::V1::ServiceProviderProfilesController < ApplicationController
  # Skip the session validation that's defined in ApplicationController
  skip_before_action :validate_session
  
  before_action :find_or_create_test_account
  before_action :find_profile, only: [:show, :update]
  
  # GET /api/v1/service_provider_profile
  def show
    if @profile
      render json: @profile
    else
      render json: { message: "Profile not found. Create one first." }, status: :not_found
    end
  end
  
  # POST /api/v1/service_provider_profile
  # POST /api/v1/service_provider_profile
 # POST /api/v1/service_provider_profile
  def create
    # Check if profile already exists for this account
    existing_profile = @jobber_account.service_provider_profile
    
    if existing_profile
      # Update existing profile instead of creating new one
      if existing_profile.update(profile_params)
        render json: existing_profile, status: :ok
      else
        Rails.logger.error "Update failed: #{existing_profile.errors.full_messages}"
        render json: { errors: existing_profile.errors.full_messages }, status: :unprocessable_entity
      end
    else
      # Create new profile with explicit jobber_account_id
      profile_data = profile_params.merge(jobber_account_id: @jobber_account.id)
      @profile = ServiceProviderProfile.new(profile_data)
      
      if @profile.save
        # NEW: Store profile ID in session for AI enhancement
        session[:service_provider_profile_id] = @profile.id
        
        render json: { success: true, data: @profile }, status: :created
      else
        render json: { success: false, errors: @profile.errors }, status: :unprocessable_entity
      end
    end
  end
  
  # PATCH /api/v1/service_provider_profile
  def update
    if @profile.update(profile_params)
      render json: @profile
    else
      render json: { errors: @profile.errors }, status: :unprocessable_entity
    end
  end
  
  private

  # Temporary: Create a test account for development
  # Temporary: Create a test account for development
  def find_or_create_test_account
    @jobber_account = JobberAccount.find_or_create_by(
      jobber_id: 'test_user_signup'
    ) do |account|
      account.name = 'Test Signup Account'
      account.jobber_id = 'test_account_123'  # Add this required field
    end
    
    Rails.logger.info "JobberAccount found/created: ID=#{@jobber_account.id}, jobber_id=#{@jobber_account.jobber_id}, name=#{@jobber_account.name}"
    Rails.logger.info "JobberAccount saved? #{@jobber_account.persisted?}"
    Rails.logger.info "JobberAccount errors: #{@jobber_account.errors.full_messages}" if @jobber_account.errors.any?
  end
  
  def find_profile
    @profile = @jobber_account.service_provider_profile
  end
  
  def profile_params
    params.require(:service_provider_profile).permit(
      :company_name, :company_description, :years_in_business, 
      :main_service_type, :service_details, :unique_selling_points,
      :local_expertise, :spring_services, :summer_services, 
      :fall_services, :winter_services, :email_tone, 
      :profile_completed
    )
  end
end