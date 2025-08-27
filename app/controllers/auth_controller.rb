# app/controllers/auth_controller.rb
# frozen_string_literal: true

class AuthController < ApplicationController
  skip_before_action :validate_session

  def index
    render json: {
      message: "ServiceFlow OAuth Setup",
      connect_jobber: request.base_url + "/auth/jobber",
      webhook_url: request.base_url + "/webhooks/jobber",
      status: "ready",
      environment: Rails.env
    }
  end

  def jobber_oauth
    begin
      Rails.logger.info "=== 🚀 STARTING OAUTH FLOW ==="
      Rails.logger.info "Environment: #{Rails.env}"
      Rails.logger.info "Base URL: #{request.base_url}"
      
      # Validate environment variables
      validate_oauth_config!
      
      # Build redirect URI
      redirect_uri = "#{request.base_url}/request_access_token"
      Rails.logger.info "Redirect URI: #{redirect_uri}"
      
      # Generate authorization URL
      jobber_service = JobberService.new
      authorization_url = jobber_service.authorization_url(redirect_uri: redirect_uri)
      Rails.logger.info "Authorization URL: #{authorization_url}"
      
      # Redirect to Jobber
      redirect_to authorization_url, allow_other_host: true
      
    rescue MissingConfigError => e
      Rails.logger.error "❌ OAuth Config Error: #{e.message}"
      render json: { 
        error: "OAuth configuration missing", 
        message: e.message,
        action: "Check your environment variables and Jobber Developer Center setup"
      }, status: 500
      
    rescue StandardError => e
      Rails.logger.error "❌ OAuth Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace[0..3].join("\n")}"
      
      render json: { 
        error: "OAuth setup failed", 
        message: e.message,
        details: "Check environment variables and Jobber Developer Center setup"
      }, status: 500
    end
  end

  def request_oauth2_access_token
    # Handle both GET and POST requests
    authorization_code = params[:code]
    error_code = params[:error]
    error_description = params[:error_description]
    
    # Check for OAuth errors from Jobber
    if error_code.present?
      Rails.logger.error "❌ OAuth Error from Jobber: #{error_code} - #{error_description}"
      return render json: { 
        error: "Authorization denied", 
        message: error_description || "User denied authorization or OAuth error occurred",
        error_code: error_code
      }, status: 400
    end
    
    # Check for authorization code
    if authorization_code.blank?
      Rails.logger.error "❌ No authorization code received"
      return render json: { 
        error: "Authorization failed", 
        message: "No authorization code received from Jobber"
      }, status: 400
    end

    Rails.logger.info "📨 Processing OAuth callback with code: #{authorization_code[0..20]}..."
    
    begin
      # Exchange code for tokens
      jobber_service = JobberService.new
      tokens = jobber_service.create_oauth2_access_token(authorization_code)
      
      if tokens.blank? || tokens[:access_token].blank?
        Rails.logger.error "❌ Failed to exchange code for tokens"
        return render json: { 
          error: "Token exchange failed",
          message: "Could not obtain access token from Jobber. Check your app configuration."
        }, status: 400
      end

      Rails.logger.info "✅ Successfully obtained access token"

      # Authenticate and create/update account
      account = jobber_service.authenticate_account(tokens)
      
      if account.blank?
        Rails.logger.error "❌ Failed to authenticate account"
        return render json: { 
          error: "Account authentication failed",
          message: "Could not retrieve account information from Jobber"
        }, status: 400
      end

      # Create session
      session[:account_id] = account.jobber_id
      Rails.logger.info "✅ OAuth completed successfully for account: #{account.name} (#{account.jobber_id})"
      
      # Return success response (this could be HTML or JSON depending on your needs)
      respond_to do |format|
        format.json do
          render json: { 
            success: true,
            account_name: account.name,
            account_id: account.jobber_id,
            message: "Successfully connected to Jobber!",
            redirect_url: "/"  # Where to redirect user after success
          }
        end
        
        format.html do
          # For direct browser access, redirect to success page or show message
          render html: success_page_html(account), layout: false
        end
      end
      
    rescue StandardError => e
      Rails.logger.error "❌ OAuth callback error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace[0..5].join("\n")}"
      
      respond_to do |format|
        format.json do
          render json: { 
            error: "OAuth processing failed",
            message: e.message
          }, status: 500
        end
        
        format.html do
          render html: error_page_html(e.message), layout: false
        end
      end
    end
  end

  def logout
    account_name = nil
    if session[:account_id].present?
      account = JobberAccount.find_by(jobber_id: session[:account_id])
      account_name = account&.name
    end
    
    reset_session
    Rails.logger.info "📝 User logged out: #{account_name}"
    
    respond_to do |format|
      format.json { render json: { success: true, message: "Logged out successfully" } }
      format.html { redirect_to root_path }
    end
  end
  
  def status
    if session[:account_id].present?
      account = JobberAccount.find_by(jobber_id: session[:account_id])
      if account
        render json: {
          authenticated: true,
          account_name: account.name,
          account_id: account.jobber_id,
          needs_reauthorization: account.needs_reauthorization?,
          token_expires_in: account.token_expires_in,
          auth_status: account.auth_status,
          setup_complete: account.setup_complete?
        }
      else
        render json: { 
          authenticated: false, 
          message: "Account not found" 
        }
      end
    else
      render json: { 
        authenticated: false, 
        message: "No active session" 
      }
    end
  end

  private

  def validate_oauth_config!
    missing = []
    missing << "JOBBER_CLIENT_ID" if ENV['JOBBER_CLIENT_ID'].blank?
    missing << "JOBBER_CLIENT_SECRET" if ENV['JOBBER_CLIENT_SECRET'].blank?
    
    if missing.any?
      raise MissingConfigError, "Missing required environment variables: #{missing.join(', ')}"
    end
  end

  def success_page_html(account)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>ServiceFlow - Connection Successful</title>
          <style>
              body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; text-align: center; }
              .success { background-color: #d4edda; border: 1px solid #c3e6cb; color: #155724; padding: 20px; border-radius: 5px; margin: 20px 0; }
              .info { background-color: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; padding: 15px; border-radius: 5px; margin: 15px 0; }
              button { padding: 10px 20px; margin: 10px; font-size: 16px; cursor: pointer; background-color: #007bff; color: white; border: none; border-radius: 5px; }
          </style>
      </head>
      <body>
          <h1>🎉 Successfully Connected to Jobber!</h1>
          
          <div class="success">
              <h3>Welcome, #{account.name}!</h3>
              <p>Your Jobber account is now connected to ServiceFlow.</p>
          </div>
          
          <div class="info">
              <p><strong>Account ID:</strong> #{account.jobber_id}</p>
              <p><strong>Connected At:</strong> #{Time.current.strftime('%B %d, %Y at %I:%M %p')}</p>
          </div>
          
          <button onclick="window.close()">Close Window</button>
          <button onclick="window.location.href='/'">Continue to Dashboard</button>
          
          <script>
              // Auto-close after 3 seconds if opened in popup
              if (window.opener) {
                  setTimeout(function() {
                      window.close();
                  }, 3000);
              }
          </script>
      </body>
      </html>
    HTML
  end

  def error_page_html(error_message)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>ServiceFlow - Connection Failed</title>
          <style>
              body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; text-align: center; }
              .error { background-color: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; padding: 20px; border-radius: 5px; margin: 20px 0; }
              button { padding: 10px 20px; margin: 10px; font-size: 16px; cursor: pointer; background-color: #dc3545; color: white; border: none; border-radius: 5px; }
              .retry-btn { background-color: #007bff; }
          </style>
      </head>
      <body>
          <h1>❌ Connection Failed</h1>
          
          <div class="error">
              <h3>Unable to connect to Jobber</h3>
              <p>#{error_message}</p>
          </div>
          
          <button onclick="window.location.href='/auth/jobber'" class="retry-btn">Try Again</button>
          <button onclick="window.location.href='/'">Back to Home</button>
          
          <script>
              console.error('OAuth Error:', '#{error_message}');
          </script>
      </body>
      </html>
    HTML
  end

  class MissingConfigError < StandardError; end
end
