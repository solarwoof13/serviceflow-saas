# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :validate_session, except: [:heartbeat, :jobber]

  def heartbeat
    head(:ok)
  end

  def debug_database
    render json: {
      environment: Rails.env,
      email_count: EmailDeduplicationLog.count,
      recent_emails: EmailDeduplicationLog.order(created_at: :desc).limit(10).map do |log|
        {
          created_at: log.created_at,
          customer_email: log.customer_email,
          email_status: log.email_status,
          webhook_topic: log.webhook_topic
        }
      end,
      account_name: JobberAccount.first&.name,
      company_name: JobberAccount.first&.service_provider_profile&.company_name
    }
  end

  private

  def jobber_account_id
    session[:account_id]
  end

  def set_jobber_account
    @jobber_account = JobberAccount.find_by(jobber_id: jobber_account_id)
  end

  def valid_access_token?
    raise Exceptions::AuthorizationException if jobber_account_id.blank?

    set_jobber_account

    raise Exceptions::AuthorizationException if @jobber_account.blank?

    @jobber_account.valid_jobber_access_token?
  end

  def refresh_access_token
    @jobber_account.refresh_jobber_access_token!
  end

  def validate_session
    refresh_access_token unless valid_access_token?
  rescue Exceptions::AuthorizationException => error
    render(json: { message: error.message }, status: :unauthorized)
  end

  def index
  # Simple OAuth trigger page
  render json: { 
    message: "ServiceFlow OAuth",
    connect_url: "/auth/jobber",
    status: "ready"
  }
  end
end
