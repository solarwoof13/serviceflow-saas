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
      token = @oauth_client.auth_code.get_token(code, redirect_uri: redirect_uri)
      {
        access_token: token.token,
        refresh_token: token.refresh_token,
        expires_at: token.expires_at,  # Handled by OAuth2 gem from expires_in
        expires_in: token.expires_in
      }
    rescue OAuth2::Error => e
      Rails.logger.error "❌ OAuth token exchange failed: #{e.message} (Code: #{e.response.status}, Body: #{e.response.body})"
      {}
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "❌ OAuth connection error: #{e.message}"
      {}
    end
  end

  def authenticate_account(tokens)
    result = execute_query(tokens[:access_token], AccountQuery)

    return if result.blank?

    account_data = result["data"]["account"]
    account_params = {
      jobber_id: account_data["id"],
      name: account_data["name"],
    }

    update_account_tokens(account_params, tokens)
  end

  def update_account_tokens(account_params, tokens)
    account = JobberAccount.find_or_create_by({ account_id: account_params[:jobber_id] })
    account.name = account_params[:name] if account_params[:name]
    account.jobber_access_token = tokens[:access_token]
    account.token_expires_at = tokens[:expires_at]               # Correct column
    account.refresh_token = tokens[:refresh_token]               # Correct column
    account.needs_reauthorization = false                        # Ensure reauthorization flag is reset
    account.save!
    account
  end

  def refresh_access_token(account)
    raise Exceptions::AuthorizationException if account.jobber_access_token.blank?

    credentials = {
      token_type: "bearer",
      access_token: account.jobber_access_token,
      expires_at: account.token_expires_at,  # Updated to correct column
      refresh_token: account.refresh_token   # Updated to correct column
    }

    tokens = OAuth2::AccessToken.from_hash(@oauth_client, credentials)  # Use instance client
    tokens = tokens.refresh!
    return if tokens.nil?

    tokens = tokens.to_hash
    tokens[:expires_at] = tokens[:expires_at]  # Already handled by gem
    tokens
  end

  def authorization_url(redirect_uri:)
    @oauth_client.auth_code.authorize_url(redirect_uri: redirect_uri, scope: 'read write')
  end

  private

  def result_has_errors?(result)
    return false if result["errors"].nil?

    raise Exceptions::GraphQLQueryError, result["errors"].first["message"]
  end

  def sleep_before_throttling(result, expected_cost = nil)
    throttle_status = result["extensions"]["cost"]["throttleStatus"]
    currently_available = throttle_status["currentlyAvailable"].to_i
    max_available = throttle_status["maximumAvailable"].to_i
    restore_rate = throttle_status["restoreRate"].to_i
    sleep_time = 0

    if expected_cost.blank?
      expected_cost = max_available * 0.6
    end
    if currently_available <= expected_cost
      sleep_time = ((max_available - currently_available) / restore_rate).ceil
      sleep(sleep_time)
    end

    sleep_time
  end
end
