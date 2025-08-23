# frozen_string_literal: true

Rails.application.routes.draw do
  root 'auth#index'
  get "/auth/jobber", to: "auth#jobber_oauth"

  post "/webhooks/jobber", to: 'webhooks#jobber'
  get "/heartbeat", to: "application#heartbeat"
  get "/logout", to: "auth#logout"
  get "/request_access_token", to: "auth#request_oauth2_access_token"
  post "/request_access_token", to: "auth#request_oauth2_access_token"
  get "/jobber_account_name", to: "jobber_accounts#jobber_account_name"
  get "/clients", to: "clients#index"

  post 'webhooks/jobber/visit_completed', to: 'jobber_webhooks#visit_completed'
  get 'webhooks/jobber/health', to: 'jobber_webhooks#health'

  namespace :webhooks do
    post "/", to: "webhook_receiver#index"
  end

  # Add API namespace for service provider profiles
  namespace :api do
    namespace :v1 do
      resource :service_provider_profile, only: [:show, :create, :update]
      post 'ai_enhancement', to: 'ai_enhancements#enhance'  # Add this line
      post 'generate_customer_email', to: 'customer_emails#generate_and_send'
      get 'email_service_status', to: 'customer_emails#preview'
    end
  end
end

