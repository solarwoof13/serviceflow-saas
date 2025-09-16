class JobberAccount < ApplicationRecord
  serialize :processed_visit_ids, Array
  
  has_many :wix_users
  has_many :visits
  has_many :email_deduplication_logs
  has_one :service_provider_profile, dependent: :destroy
  
  validates :account_id, presence: true, uniqueness: true
  
  # Check if visit was already processed
  def visit_processed?(visit_id)
    processed_visit_ids.include?(visit_id.to_s)
  end
  
  # Mark visit as processed
  def mark_visit_processed!(visit_id)
    self.processed_visit_ids << visit_id.to_s
    save!
  end
  
  # Existing methods...
  def valid_jobber_access_token?
    return false if jobber_access_token.blank?
    return false if token_expires_at.blank?
    return false if needs_reauthorization?
    
    token_expires_at > 5.minutes.from_now
  end
  
  def get_valid_access_token
    if valid_jobber_access_token?
      Rails.logger.info "✅ Using existing valid token"
      jobber_access_token
    else
      Rails.logger.info "🔄 Token invalid/expired, attempting refresh..."
      OauthRefreshService.get_valid_token(self)
    end
  end
  
  def primary_wix_user
    wix_users.active.first
  end
end