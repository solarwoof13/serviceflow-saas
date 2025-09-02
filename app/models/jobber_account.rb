class JobberAccount < ApplicationRecord
  validates :jobber_id, presence: true, uniqueness: true
  # Removed jobber_id validation - consolidating on jobber_id only
  # Add this alias to map access_token to your existing jobber_access_token column
  alias_attribute :access_token, :jobber_access_token
  has_one :service_provider_profile, dependent: :destroy
  

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
      Rails.logger.info "Using existing valid token for #{display_name}"
      jobber_access_token
    else
      Rails.logger.info "Token invalid/expired for #{display_name}, attempting refresh..."
      if refresh_jobber_access_token!
        jobber_access_token
      else
        Rails.logger.error "Token refresh failed for #{display_name}"
        nil
      end
    end
  end
  
  # Manual refresh method
  def refresh_jobber_access_token!
    service = JobberService.new
    tokens = service.refresh_access_token(self)
    
    if tokens && tokens[:access_token].present?
      update!(
        jobber_access_token: tokens[:access_token],
        token_expires_at: tokens[:expires_at],
        refresh_token: tokens[:refresh_token],
        needs_reauthorization: false
      )
      Rails.logger.info "Token refreshed successfully for #{display_name}"
      self # Return self for chaining
    else
      Rails.logger.error "Token refresh returned no valid tokens for #{display_name}"
      mark_needs_reauthorization!
      false
    end
  rescue StandardError => e
    Rails.logger.error "Token refresh error for #{display_name}: #{e.message}"
    mark_needs_reauthorization!
    false
  end
  
  # Mark account as needing user re-authorization
  def mark_needs_reauthorization!
    update!(
      jobber_access_token: nil,
      refresh_token: nil,
      token_expires_at: nil,
      needs_reauthorization: true
    )
    Rails.logger.warn "Account #{display_name} marked as needing reauthorization"
  end
  
  # Legacy method for backward compatibility (used by old specs)
  def clear_jobber_credentials!
    mark_needs_reauthorization!
  end
  
  # Helper method to get or create profile
  def get_or_create_profile
    service_provider_profile || create_service_provider_profile
  end
  
  # Check if account setup is complete
  def setup_complete?
    service_provider_profile&.setup_complete?
  end
  
  # Get display name for logging
  def display_name
    name.presence || jobber_id
  end
  
  # Token expiry information
  def token_expires_in
    return nil if token_expires_at.blank?
    
    seconds = (token_expires_at - Time.current).to_i
    return nil if seconds <= 0
    
    if seconds < 3600 # Less than 1 hour
      "#{(seconds / 60).round} minutes"
    elsif seconds < 86400 # Less than 1 day
      "#{(seconds / 3600).round} hours"
    else
      "#{(seconds / 86400).round} days"
    end
  end
  
  # Status for admin/debugging
  def auth_status
    if needs_reauthorization?
      "needs_reauth"
    elsif jobber_access_token.blank?
      "no_token"
    elsif valid_jobber_access_token?
      "active"
    else
      "expired"
    end
  end

  # 🔧 ADD THIS NEW METHOD HERE (after auth_status method):
  def self.find_or_merge_by_jobber_id(jobber_id, attributes = {})
    puts "🔍 DEBUG: find_or_merge_by_jobber_id called with: #{jobber_id}"
    
    # Exact match first
    existing_accounts = where(jobber_id: jobber_id)
    puts "🔍 DEBUG: Found #{existing_accounts.count} exact matches"
    
    # Also check for accounts with similar jobber_ids (same account ID)
    account_part = jobber_id.split('/').last # Extract "Njg1MzA4" from the full ID
    similar_accounts = JobberAccount.where("jobber_id LIKE ?", "%#{account_part}%").where.not(id: existing_accounts.pluck(:id))
    puts "🔍 DEBUG: Found #{similar_accounts.count} similar accounts"
    
    all_accounts = existing_accounts + similar_accounts
    puts "🔍 DEBUG: Total accounts found: #{all_accounts.count}"
    
    all_accounts.each do |acc|
      puts "🔍 DEBUG: Account ID: #{acc.id}, Jobber ID: #{acc.jobber_id}, Name: #{acc.name}, Has Profile: #{acc.service_provider_profile.present?}"
    end
    
    if all_accounts.count > 1
      # Always prefer account with business profile
      account_with_profile = all_accounts.find { |acc| acc.service_provider_profile.present? }
      
      if account_with_profile
        puts "🔍 DEBUG: Found account with profile: ID #{account_with_profile.id}"
        
        # Delete others
        all_accounts.reject { |acc| acc.id == account_with_profile.id }.each do |acc|
          puts "🔍 DEBUG: Deleting duplicate account ID: #{acc.id}"
          acc.destroy
        end
        
        return account_with_profile
      else
        puts "🔍 DEBUG: No account has profile, keeping first"
        return all_accounts.first
      end
    elsif all_accounts.count == 1
      puts "🔍 DEBUG: Returning single account ID: #{all_accounts.first.id}"
      return all_accounts.first
    else
      # Create new account
      puts "🔍 DEBUG: Creating new account"
      new_account = create!(attributes.merge(jobber_id: jobber_id))
      puts "🔍 DEBUG: Created account ID: #{new_account.id}"
      return new_account
    end
  end
end
