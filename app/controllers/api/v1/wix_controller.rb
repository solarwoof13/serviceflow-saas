class Api::V1::WixController < ApplicationController

  before_action :authenticate_wix_request
  
  def create_user
    # Wix sends "Startup", "Growth", or "Elite"
    plan = normalize_plan_name(params[:plan])
    
    wix_user = WixUser.find_or_create_by(wix_user_id: params[:wix_user_id]) do |user|
      user.email = params[:email]
      user.display_name = params[:display_name]
      user.subscription_plan = plan
      user.retention_days = WixUser::RETENTION_DAYS[plan]
      user.email_limit = WixUser::EMAIL_LIMITS[plan]
      user.billing_period_start = Time.current
      user.billing_period_end = 1.month.from_now
    end
    
    render json: { 
      success: true, 
      user_id: wix_user.id,
      plan_display_name: wix_user.display_plan_name
    }
  end
  
  def update_subscription
    wix_user = WixUser.find_by!(wix_user_id: params[:wix_user_id])
    plan = normalize_plan_name(params[:plan])
    
    wix_user.update!(
      subscription_plan: plan,
      retention_days: WixUser::RETENTION_DAYS[plan],
      email_limit: WixUser::EMAIL_LIMITS[plan]
    )
    
    render json: { 
      success: true,
      plan_display_name: wix_user.display_plan_name
    }
  end
  
  private
  
  def normalize_plan_name(plan)
    WixUser::PLAN_MAPPING[plan] || 'basic'
  end
  
  def authenticate_wix_request
    # TODO: Implement Wix webhook signature verification
    # For now, you can use a shared secret in headers
    unless request.headers['X-Wix-Signature'] == ENV['WIX_WEBHOOK_SECRET']
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end