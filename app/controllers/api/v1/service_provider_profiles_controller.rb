class Api::V1::ServiceProviderProfilesController < AuthController
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
  def create
    @profile = @jobber_account.build_service_provider_profile(profile_params)
    
    if @profile.save
      render json: @profile, status: :created
    else
      render json: { errors: @profile.errors }, status: :unprocessable_entity
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
  
  def find_profile
    @profile = @jobber_account.service_provider_profile
  end
  
  def profile_params
    params.require(:service_provider_profile).permit(
      :company_name, :company_description, :years_in_business, 
      :main_service_type, :service_details, :equipment_methods,
      :unique_selling_points, :certifications_licenses, :local_expertise,
      :spring_services, :summer_services, :fall_services, :winter_services,
      :email_tone, :always_include, :never_mention, :profile_completed,
      service_areas: []
    )
  end
end