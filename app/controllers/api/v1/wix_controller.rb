# app/controllers/api/v1/wix_controller.rb
class Api::V1::WixController < ApplicationController
  skip_before_action :validate_session
  
  def sync_user
    wix_data = params[:wix_user]
    
    wix_user = WixUser.find_or_create_by(wix_id: wix_data[:wix_id]) do |user|
      user.email = wix_data[:email]
      user.settings = wix_data[:settings] || {}
    end
    
    # Update subscription
    subscription = wix_user.subscription || wix_user.build_subscription
    subscription.level = wix_data[:subscription_level]
    subscription.save
    
    # Sync features based on level
    sync_features_for_subscription(subscription)
    
    render json: { success: true, user_id: wix_user.id }
  end
  
  def get_subscription_status
    wix_user = WixUser.find_by(wix_id: params[:wix_id])
    return render json: { error: 'User not found' }, status: :not_found unless wix_user
    
    render json: {
      level: wix_user.subscription&.level,
      features: wix_user.features.pluck(:name),
      settings: wix_user.settings
    }
  end
  
  private
  
  def sync_features_for_subscription(subscription)
    features = Feature::LEVEL_FEATURES[subscription.level.to_sym] || []
    
    subscription.subscription_features.destroy_all
    
    features.each do |feature_name|
      feature = Feature.find_or_create_by(name: feature_name)
      subscription.subscription_features.create(feature: feature)
    end
  end
end
