# app/controllers/concerns/subscription_gates.rb
module SubscriptionGates
  extend ActiveSupport::Concern
  
  def current_wix_user
    # Support both session (production) and params (testing)
    wix_id = session[:wix_user_id] || params[:wix_user_id]
    @current_wix_user ||= WixUser.find_by(wix_id: wix_id)
  end
  
  def has_feature?(feature_name)
    return false unless current_wix_user
    current_wix_user.features.exists?(name: feature_name)
  end
  
  def require_feature(feature_name)
    unless has_feature?(feature_name)
      render json: { 
        error: "#{feature_name.titleize} requires an upgraded subscription",
        upgrade_url: 'https://www.serviceflow.tech/pricing'
      }, status: :forbidden
      return false
    end
    true
  end
end