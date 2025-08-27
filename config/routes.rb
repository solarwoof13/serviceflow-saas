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
      resource :service_provider_profile, only: [:show, :create, :update] do
        member do
          get :status
          post :complete_setup
        end
      end
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

