# frozen_string_literal: true

class JobberService
  include Graphql::Queries::Account

  JOBBER_SITE = 'https://api.getjobber.com'
  JOBBER_AUTHORIZE_PATH = '/api/oauth/authorize'
  JOBBER_TOKEN_PATH = '/api/oauth/token'

  def initialize
    @client_id = ENV['JOBBER_CLIENT_ID'] || Rails.configuration.x.jobber.client_id
    @client_secret = ENV['JOBBER_CLIENT_SECRET'] || Rails.configuration.x.jobber.client_secret
    @oauth_client = OAuth2::Client.new(
      @client_id,
      @client_secret,
      site: JOBBER_SITE,
      authorize_url: JOBBER_AUTHORIZE_PATH,
      token_url: JOBBER_TOKEN_PATH
    )
  end

  def execute_query(token, query, variables = {}, expected_cost: nil)
    context = { Authorization: "Bearer #{token}" }
    result = JobberAppTemplateRailsApi::Client.query(query, variables: variables, context: context)
    result = result.original_hash

    result_has_errors?(result)
    sleep_before_throttling(result, expected_cost)
    result
  end

  def execute_paginated_query(token, query, variables, resource_names, paginated_results = [], expected_cost: nil)
    result = execute_query(token, query, variables, expected_cost: expected_cost)

    result = result["data"]

    resource_names.each do |resource|
      result = result[resource].deep_dup
    end

    paginated_results << result["nodes"]
    page_info = result["pageInfo"]
    has_next_page = page_info["hasNextPage"]

    if has_next_page
      variables[:cursor] = page_info["endCursor"]
      execute_paginated_query(token, query, variables, resource_names, paginated_results, expected_cost: expected_cost)
    end

    paginated_results.flatten
  end

  def create_oauth2_access_token(code)
    return {} if code.blank?

    redirect_uri = "#{ENV['APP_BASE_URL'] || 'https://serviceflow-saas.onrender.com'}/request_access_token"

    begin
      Rails.logger.info "🔄 Exchanging authorization code for tokens..."
      Rails.logger.info "Using redirect URI: #{redirect_uri}"
      
      token = @oauth_client.auth_code.get_token(code, redirect_uri: redirect_uri)
      
      result = {
        access_token: token.token,
        refresh_token: token.refresh_token,
        expires_at: token.expires_at ? Time.at(token.expires_at) : nil,
        expires_in: token.expires_in
      }
      
      Rails.logger.info "✅ Successfully exchanged code for access token"
      result
      
    rescue OAuth2::Error => e
      Rails.logger.error "❌ OAuth token exchange failed: #{e.message}"
      Rails.logger.error "❌ Response Code: #{e.response.status}"
      Rails.logger.error "❌ Response Body: #{e.response.body}"
      {}
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "❌ OAuth connection error: #{e.message}"
      {}
    end
  end

  def authenticate_account(tokens)
    result = execute_query(tokens[:access_token], AccountQuery)

    return if result.blank? || result["errors"].present?

    account_data = result["data"]["account"]
    account_params = {
      jobber_id: account_data["id"],
      name: account_data["name"],
    }

    update_account_tokens(account_params, tokens)
  end

  def update_account_tokens(account_params, tokens)
    # Use find_or_create_by with the correct unique field (jobber_id)
    account = JobberAccount.find_or_create_by(jobber_id: account_params[:jobber_id]) do |new_account|
      # Set account_id for new accounts (required by validation)
      new_account.account_id = account_params[:jobber_id]
      new_account.name = account_params[:name]
    end
    
    # Update existing account name if it changed
    account.name = account_params[:name] if account_params[:name]
    
    # Update token information using CORRECT column names
    account.jobber_access_token = tokens[:access_token]
    account.token_expires_at = tokens[:expires_at]       # Correct column name
    account.refresh_token = tokens[:refresh_token]       # Correct column name
    account.needs_reauthorization = false
    
    account.save!
    
    Rails.logger.info "✅ Updated JobberAccount: #{account.name} (ID: #{account.jobber_id})"
    account
  end

  def refresh_access_token(account)
    raise Exceptions::AuthorizationException if account.jobber_access_token.blank?

    # Build credentials hash with correct column names
    credentials = {
      token_type: "bearer",
      access_token: account.jobber_access_token,
      expires_at: account.token_expires_at&.to_i,  # Convert to Unix timestamp
      refresh_token: account.refresh_token         # Use correct column name
    }

    begin
      Rails.logger.info "🔄 Refreshing access token for account: #{account.jobber_id}"
      
      tokens = OAuth2::AccessToken.from_hash(@oauth_client, credentials)
      refreshed_tokens = tokens.refresh!
      
      return nil if refreshed_tokens.nil?

      result = {
        access_token: refreshed_tokens.token,
        refresh_token: refreshed_tokens.refresh_token,
        expires_at: refreshed_tokens.expires_at ? Time.at(refreshed_tokens.expires_at) : nil,
        expires_in: refreshed_tokens.expires_in
      }
      
      Rails.logger.info "✅ Token refresh successful"
      result
      
    rescue OAuth2::Error => e
      Rails.logger.error "❌ Token refresh failed: #{e.message}"
      Rails.logger.error "❌ Response Code: #{e.response.status}"
      Rails.logger.error "❌ Response Body: #{e.response.body}"
      nil
    rescue StandardError => e
      Rails.logger.error "❌ Token refresh error: #{e.message}"
      nil
    end
  end

  def authorization_url(redirect_uri:)
    @oauth_client.auth_code.authorize_url(
      redirect_uri: redirect_uri, 
      scope: 'read write'
    )
  end

  private

  def result_has_errors?(result)
    return false if result["errors"].nil?

    Rails.logger.error "❌ GraphQL Query Error: #{result['errors'].first['message']}"
    raise Exceptions::GraphQLQueryError, result["errors"].first["message"]
  end

  def sleep_before_throttling(result, expected_cost = nil)
    return 0 unless result.dig("extensions", "cost", "throttleStatus")
    
    throttle_status = result["extensions"]["cost"]["throttleStatus"]
    currently_available = throttle_status["currentlyAvailable"].to_i
    max_available = throttle_status["maximumAvailable"].to_i
    restore_rate = throttle_status["restoreRate"].to_i
    sleep_time = 0

    expected_cost = max_available * 0.6 if expected_cost.blank?
    
    if currently_available <= expected_cost
      sleep_time = ((max_available - currently_available) / restore_rate).ceil
      Rails.logger.info "😴 Sleeping #{sleep_time}s for rate limiting..."
      sleep(sleep_time)
    end

    sleep_time
  end
end