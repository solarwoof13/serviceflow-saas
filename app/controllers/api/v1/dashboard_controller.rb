# app/controllers/api/v1/dashboard_controller.rb
class Api::V1::DashboardController < ApplicationController
  include SubscriptionGates
  skip_before_action :validate_session
  
  def index
    # Basic dashboard data available to all
    dashboard_data = {
      user_info: current_wix_user&.as_json(only: [:email, :settings]),
      subscription_level: current_wix_user&.subscription&.level,
      available_features: current_wix_user&.features&.pluck(:name) || []
    }
    
    render json: dashboard_data
  end
  
  def cached_emails
    # Check cache feature
    if has_feature?('unlimited_cache')
      emails = get_emails_unlimited
    elsif has_feature?('extended_cache')
      emails = get_emails_extended
    else
      emails = get_emails_limited
    end
    
    render json: { emails: emails, cache_type: cache_type_description }
  end
  
  def visit_records
    # Check records feature
    if has_feature?('unlimited_records')
      records = get_records_unlimited
    elsif has_feature?('extended_records')
      records = get_records_extended
    else
      records = get_records_limited
    end
    
    render json: { records: records, record_type: record_type_description }
  end
  
  def smart_reviews
    return unless require_feature('smart_reviews')
    
    # Smart review logic for Growth/Elite
    reviews = generate_smart_reviews
    render json: { reviews: reviews, type: 'smart' }
  end
  
  def google_reviews
    if has_feature?('advanced_reviews')
      reviews = generate_advanced_reviews
      type = 'advanced'
    elsif has_feature?('smart_reviews')
      reviews = generate_smart_reviews
      type = 'smart'
    else
      reviews = generate_basic_reviews
      type = 'basic'
    end
    
    render json: { reviews: reviews, type: type }
  end
  
  private
  
  def cache_type_description
    if has_feature?('unlimited_cache')
      'unlimited'
    elsif has_feature?('extended_cache')
      '7 days'
    else
      '24 hours'
    end
  end
  
  def record_type_description
    if has_feature?('unlimited_records')
      'unlimited'
    elsif has_feature?('extended_records')
      '90 days'
    else
      '30 days'
    end
  end
  
  def get_emails_limited
    # Startup: 24 hours
    current_wix_user.emails.where('created_at > ?', 24.hours.ago).limit(10)
  end
  
  def get_emails_extended
    # Growth: 7 days
    current_wix_user.emails.where('created_at > ?', 7.days.ago).limit(50)
  end
  
  def get_emails_unlimited
    # Elite: unlimited
    current_wix_user.emails.limit(100)
  end
  
  def get_records_limited
    # Startup: 30 days
    current_wix_user.visits.where('created_at > ?', 30.days.ago).limit(10)
  end
  
  def get_records_extended
    # Growth: 90 days
    current_wix_user.visits.where('created_at > ?', 90.days.ago).limit(50)
  end
  
  def get_records_unlimited
    # Elite: unlimited
    current_wix_user.visits.limit(100)
  end
  
  def generate_basic_reviews
    # Basic review prompts
    ['Please leave a review', 'How was our service?']
  end
  
  def generate_smart_reviews
    # Smart review logic
    ['Thank you for choosing us! Please share your experience on Google.', 
     'We hope you loved our service. Would you mind leaving a review?']
  end
  
  def generate_advanced_reviews
    # Advanced review with personalization
    customer_name = current_wix_user.settings['customer_name'] || 'Valued Customer'
    ["#{customer_name}, your feedback means the world to us. Please share your experience on Google."]
  end
end
