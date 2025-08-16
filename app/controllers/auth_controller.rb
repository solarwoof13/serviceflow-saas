# frozen_string_literal: true

class AuthController < ApplicationController
  skip_before_action :validate_session

  def index
    render json: {
      message: "ServiceFlow OAuth Setup",
      connect_jobber: request.base_url + "/auth/jobber",
      webhook_url: request.base_url + "/webhooks/jobber",
      status: "ready"
    }
  end

  def jobber_oauth
    puts "=== STARTING OAUTH FLOW ==="
    puts "Base URL: #{request.base_url}"
    
    jobber_service = JobberService.new
    redirect_uri = "#{request.base_url}/request_access_token"
    puts "Redirect URI: #{redirect_uri}"
    
    authorization_url = jobber_service.authorization_url(redirect_uri: redirect_uri)
    puts "Auth URL: #{authorization_url}"
    
    redirect_to authorization_url, allow_other_host: true
  end

  def request_oauth2_access_token
    tokens = jobber_service.create_oauth2_access_token(params[:code].to_s)

    return if tokens.blank? || tokens[:access_token].blank?

    account = jobber_service.authenticate_account(tokens)

    return if account.blank?

    session[:account_id] = account.jobber_id

    render(json: { accountName: account.name })
  end

  def logout
    reset_session
    head(:ok)
  end

  private

  def jobber_service
    JobberService.new
  end
end
