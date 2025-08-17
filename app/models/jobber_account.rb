# app/models/jobber_account.rb
class JobberAccount < ApplicationRecord
  validates :account_id, presence: true, uniqueness: true
  
  # Check if the access token is still valid
  def valid_jobber_access_token?
    return false if jobber_access_token.blank?
    return false if token_expires_at.blank?
    return false if needs_reauthorization?
    
    # Token is valid if it doesn't expire for at least 5 minutes
    token_expires_at > 5.minutes.from_now
  end
  
  # Get a valid access token (refresh if needed)
  def get_valid_access_token
    if valid_jobber_access_token?
      Rails.logger.info "✅ Using existing valid token"
      jobber_access_token
    else
      Rails.logger.info "🔄 Token invalid/expired, attempting refresh..."
      OauthRefreshService.get_valid_token(self)
    end
  end
  
  # Manual refresh method
  def refresh_jobber_access_token!
    OauthRefreshService.refresh_access_token(self)
  end
  
  # Mark account as needing user re-authorization
  def mark_needs_reauthorization!
    update!(
      jobber_access_token: nil,
      refresh_token: nil,
      token_expires_at: nil,
      needs_reauthorization: true
    )
  end
end
