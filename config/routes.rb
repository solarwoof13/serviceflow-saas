# config/routes.rb
# frozen_string_literal: true

Rails.application.routes.draw do
  root 'auth#index'
  
  # OAuth routes - Core authentication flow
  get "/auth/jobber", to: "auth#jobber_oauth"
  get "/request_access_token", to: "auth#request_oauth2_access_token"
  post "/request_access_token", to: "auth#request_oauth2_access_token"
  get "/auth/status", to: "auth#status"
  get "/logout", to: "auth#logout"
  
  # Webhooks - Jobber integration
  post "/webhooks/jobber", to: 'webhooks#jobber'
  
  # Legacy webhook namespace (if you have other webhook handlers)
  namespace :webhooks do
    post "/", to: "webhook_receiver#index"
  end
  
  # API endpoints for authenticated users
  get "/jobber_account_name", to: "jobber_accounts#jobber_account_name"
  get "/clients", to: "clients#index"
  
  # Service provider profile management API
  namespace :api do
    namespace :v1 do
      resource :service_provider_profile, only: [:show, :create, :update]
      post :enhance_text, to: 'ai_enhancements#enhance'
    end
  end

  namespace :api do
    namespace :v1 do
      # Wix integration
      post 'wix/sync_user', to: 'wix#sync_user'
      get 'wix/subscription_status', to: 'wix#get_subscription_status'
      
      # Dashboard (ADD THESE)
      get 'dashboard', to: 'dashboard#index'
      get 'dashboard/cached_emails', to: 'dashboard#cached_emails'
      get 'dashboard/visit_records', to: 'dashboard#visit_records'
      get 'dashboard/smart_reviews', to: 'dashboard#smart_reviews'
      get 'dashboard/google_reviews', to: 'dashboard#google_reviews'
    end
  end
  
  # Health check and monitoring
  get "/heartbeat", to: "application#heartbeat"
  get "/health", to: "application#heartbeat"
  
  # Development and testing routes (only in development)
  if Rails.env.development?
    get "/test/oauth", to: redirect("/oauth_test.html")
    get "/test/webhook", to: "webhooks#test"
  end
end

