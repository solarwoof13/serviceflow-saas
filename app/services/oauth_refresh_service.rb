# app/services/oauth_refresh_service.rb
class OauthRefreshService
    JOBBER_TOKEN_URL = 'https://api.getjobber.com/api/oauth/token'
    
    def self.refresh_access_token(account)
      Rails.logger.info "🔄 Refreshing OAuth token for account: #{account.id}"
      
      if account.refresh_token.blank?
        Rails.logger.error "❌ No refresh token found for account"
        return false
      end
      
      payload = {
        grant_type: 'refresh_token',
        refresh_token: account.refresh_token,
        client_id: ENV['JOBBER_CLIENT_ID'],
        client_secret: ENV['JOBBER_CLIENT_SECRET']
      }
      
      headers = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
      
      begin
        Rails.logger.info "📡 Making token refresh request to Jobber..."
        
        response = HTTParty.post(
          JOBBER_TOKEN_URL,
          headers: headers,
          body: payload.to_json,
          timeout: 30
        )
        
        Rails.logger.info "📡 Token refresh response code: #{response.code}"
        
        if response.code == 200
          token_data = response.parsed_response
          Rails.logger.info "✅ Token refresh successful!"
          
          # Update the account with new tokens
          account.update!(
            jobber_access_token: token_data['access_token'],
            refresh_token: token_data['refresh_token'], # New refresh token
            token_expires_at: Time.current + token_data['expires_in'].seconds
          )
          
          Rails.logger.info "✅ Account tokens updated successfully"
          return true
          
        elsif response.code == 401
          Rails.logger.error "❌ Refresh token expired or invalid - user needs to re-authorize"
          # Mark account as needing re-authorization
          account.update!(
            jobber_access_token: nil,
            refresh_token: nil,
            token_expires_at: nil,
            needs_reauthorization: true
          )
          return false
          
        else
          Rails.logger.error "❌ Token refresh failed - HTTP #{response.code}"
          Rails.logger.error "❌ Response: #{response.body}"
          return false
        end
        
      rescue StandardError => e
        Rails.logger.error "❌ Token refresh error: #{e.message}"
        Rails.logger.error "❌ Backtrace: #{e.backtrace.first(3)}"
        return false
      end
    end
    
    # Check if token needs refresh (within 5 minutes of expiry)
    def self.token_needs_refresh?(account)
      return true if account.token_expires_at.blank?
      return true if account.jobber_access_token.blank?
      
      # Refresh if expires within 5 minutes
      account.token_expires_at <= 5.minutes.from_now
    end
    
    # Auto-refresh if needed, return valid token
    def self.get_valid_token(account)
      if token_needs_refresh?(account)
        Rails.logger.info "🔄 Token needs refresh, attempting refresh..."
        
        if refresh_access_token(account)
          account.reload # Get fresh data from DB
          return account.jobber_access_token
        else
          Rails.logger.error "❌ Token refresh failed"
          return nil
        end
      else
        Rails.logger.info "✅ Token still valid, no refresh needed"
        return account.jobber_access_token
      end
    end
  end