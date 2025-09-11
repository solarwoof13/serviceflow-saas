class Api::V1::WixIntegrationController < ApplicationController
  skip_before_action :validate_session, only: [:create_user, :authenticate, :webhook]
  before_action :authenticate_wix_user, except: [:create_user, :authenticate, :webhook]
  before_action :verify_wix_webhook, only: [:webhook]
  
  # POST /api/v1/wix/create_user
  def create_user
    begin
      user_params = params.require(:user).permit(
        :wix_member_id, :email, :company_name, :subscription_level, :trial_days_remaining
      )
      
      # Check if user already exists
      existing_user = WixUser.find_by(wix_member_id: user_params[:wix_member_id])
      if existing_user
        render json: { success: true, data: existing_user.as_json(except: [:api_token]) }
        return
      end
      
      # Create new Wix user
      wix_user = WixUser.create!(user_params)
      
      # Create associated JobberAccount (not connected yet)
      jobber_account = JobberAccount.create!(
        jobber_id: "wix_#{wix_user.id}",
        name: user_params[:company_name],
        wix_user: wix_user
      )
      
      # Create ServiceProviderProfile
      profile = ServiceProviderProfile.create!(
        jobber_account: jobber_account,
        wix_user: wix_user,
        company_name: user_params[:company_name],
        email_tone: 'professional',
        profile_completed: false
      )
      
      render json: {
        success: true,
        data: {
          id: wix_user.id,
          api_token: wix_user.api_token,
          company_name: wix_user.company_name,
          subscription_level: wix_user.subscription_level
        }
      }
      
    rescue ActiveRecord::RecordInvalid => e
      render json: { success: false, error: e.message }, status: 422
    rescue => e
      Rails.logger.error "Create user error: #{e.message}"
      render json: { success: false, error: "Failed to create user" }, status: 500
    end
  end
  
  # POST /api/v1/wix/authenticate
  def authenticate
    begin
      wix_member_id = params[:wix_member_id]
      email = params[:email]
      
      wix_user = WixUser.find_by(wix_member_id: wix_member_id, email: email)
      
      if wix_user
        # Update last login
        wix_user.update(last_login: Time.current)
        
        render json: {
          success: true,
          data: {
            id: wix_user.id,
            api_token: wix_user.api_token,
            subscription_level: wix_user.subscription_level,
            trial_days_remaining: wix_user.trial_days_remaining
          }
        }
      else
        render json: { success: false, error: "User not found" }, status: 404
      end
      
    rescue => e
      Rails.logger.error "Authentication error: #{e.message}"
      render json: { success: false, error: "Authentication failed" }, status: 500
    end
  end
  
  # GET /api/v1/wix/dashboard_data
  def dashboard_data
    begin
      profile = @current_wix_user.service_provider_profile
      jobber_account = profile&.jobber_account
      
      # Calculate metrics
      email_stats = calculate_email_stats(@current_wix_user)
      recent_activity = get_recent_activity(@current_wix_user)
      
      render json: {
        success: true,
        data: {
          # User Profile Info
          company_name: profile&.company_name || @current_wix_user.company_name,
          service_type: profile&.main_service_type,
          profile_completed: profile&.profile_completed || false,
          
          # Subscription Info
          subscription_level: @current_wix_user.subscription_level,
          trial_days_remaining: @current_wix_user.trial_days_remaining,
          subscription_active: @current_wix_user.subscription_active?,
          
          # Jobber Integration Status
          jobber_connected: jobber_account&.access_token.present? || false,
          jobber_account_name: jobber_account&.name,
          last_sync: jobber_account&.updated_at,
          
          # Email Metrics
          emails_sent: email_stats[:total_sent],
          ai_enhancements: email_stats[:ai_enhanced],
          customer_responses: email_stats[:responses],
          customer_satisfaction: calculate_satisfaction_score(@current_wix_user),
          
          # Financial Metrics
          time_saved: email_stats[:time_saved],
          value_saved: email_stats[:value_saved],
          
          # Recent Activity
          recent_jobs: recent_activity[:jobs],
          recent_emails: recent_activity[:emails],
          visits_this_month: recent_activity[:visits_count]
        }
      }
      
    rescue => e
      Rails.logger.error "Dashboard data error: #{e.message}"
      render json: { success: false, error: e.message }, status: 500
    end
  end
  
  # GET /api/v1/wix/service_insights
  def service_insights
    begin
      profile = @current_wix_user.service_provider_profile
      
      render json: {
        success: true,
        data: {
          # Profile completion analysis
          profile_completion: calculate_profile_completion(profile),
          
          # Current profile data
          company_name: profile&.company_name,
          company_description: profile&.company_description,
          years_in_business: profile&.years_in_business,
          main_service_type: profile&.main_service_type,
          service_details: profile&.service_details,
          unique_selling_points: profile&.unique_selling_points,
          local_expertise: profile&.local_expertise,
          email_tone: profile&.email_tone,
          always_include: profile&.always_include,
          never_mention: profile&.never_mention,
          
          # Seasonal services data
          seasonal_services: {
            spring_services: profile&.spring_services,
            summer_services: profile&.summer_services,
            fall_services: profile&.fall_services,
            winter_services: profile&.winter_services
          },
          
          # AI insights
          email_tone_effectiveness: analyze_email_tone_performance(profile),
          improvement_suggestions: generate_improvement_suggestions(profile)
        }
      }
      
    rescue => e
      Rails.logger.error "Service insights error: #{e.message}"
      render json: { success: false, error: e.message }, status: 500
    end
  end
  
  # POST /api/v1/wix/webhook
  def webhook
    begin
      event_type = params[:event_type]
      data = params[:data]
      
      case event_type
      when 'subscription_updated'
        handle_subscription_update(data)
      when 'member_deleted'
        handle_member_deletion(data)
      when 'profile_updated'
        handle_profile_update(data)
      end
      
      render json: { success: true }
      
    rescue => e
      Rails.logger.error "Webhook error: #{e.message}"
      render json: { success: false, error: e.message }, status: 500
    end
  end
  
  private
  
  def authenticate_wix_user
    auth_header = request.headers['Authorization']
    return render json: { error: 'No authorization header' }, status: 401 unless auth_header
    
    token = auth_header.split(' ').last
    @current_wix_user = WixUser.find_by(api_token: token)
    
    return render json: { error: 'Invalid token' }, status: 401 unless @current_wix_user
    
    # Check if subscription is active
    unless @current_wix_user.subscription_active?
      return render json: { 
        error: 'Subscription expired', 
        trial_expired: true,
        upgrade_url: ENV['WIX_UPGRADE_URL'] 
      }, status: 402
    end
  end
  
  def verify_wix_webhook
    # Implement webhook signature verification if needed
    true
  end
  
  def calculate_email_stats(wix_user)
    profile = wix_user.service_provider_profile
    return default_email_stats unless profile
    
    total_sent = EmailDeduplicationLog.joins(jobber_account: :wix_user)
                                     .where(wix_users: { id: wix_user.id })
                                     .count
    
    ai_enhanced = EmailDeduplicationLog.joins(jobber_account: :wix_user)
                                      .where(wix_users: { id: wix_user.id }, ai_enhanced: true)
                                      .count
    
    # Calculate time and value saved
    time_saved = total_sent * 0.25 # 15 minutes per email
    value_saved = time_saved * 30  # $30/hour rate
    
    {
      total_sent: total_sent,
      ai_enhanced: ai_enhanced,
      responses: calculate_response_count(wix_user),
      time_saved: time_saved,
      value_saved: value_saved
    }
  end
  
  def default_email_stats
    {
      total_sent: 0,
      ai_enhanced: 0,
      responses: 0,
      time_saved: 0,
      value_saved: 0
    }
  end
  
  def calculate_profile_completion(profile)
    return { percentage: 0, missing_required: [] } unless profile
    
    required_fields = %w[company_name company_description years_in_business 
                        main_service_type service_details unique_selling_points]
    
    completed = required_fields.count { |field| profile.send(field).present? }
    missing = required_fields.reject { |field| profile.send(field).present? }
    
    {
      percentage: (completed.to_f / required_fields.length * 100).round,
      completed_required: completed,
      total_required: required_fields.length,
      missing_required: missing
    }
  end
  
  def handle_subscription_update(data)
    wix_user = WixUser.find_by(wix_member_id: data[:member_id])
    return unless wix_user
    
    wix_user.update(
      subscription_level: data[:subscription_level],
      trial_days_remaining: data[:trial_days_remaining] || 0
    )
  end
  
  def handle_member_deletion(data)
    wix_user = WixUser.find_by(wix_member_id: data[:member_id])
    return unless wix_user
    
    # Soft delete or cleanup user data
    wix_user.update(deleted_at: Time.current)
  end
end