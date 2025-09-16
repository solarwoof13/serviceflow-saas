class WixUser < ApplicationRecord
  # Map frontend names to backend names
  PLAN_MAPPING = {
    'Startup' => 'basic',
    'Growth' => 'pro',
    'Elite' => 'enterprise',
    # Also support lowercase
    'startup' => 'basic',
    'growth' => 'pro',
    'elite' => 'enterprise',
    # And direct mapping
    'basic' => 'basic',
    'pro' => 'pro',
    'enterprise' => 'enterprise'
  }.freeze
  
  RETENTION_DAYS = {
    'basic' => 60,
    'pro' => 90,
    'enterprise' => 180
  }.freeze
  
  EMAIL_LIMITS = {
    'basic' => 65,
    'pro' => 420,
    'enterprise' => 1550
  }.freeze
  
  belongs_to :jobber_account, optional: true
  has_many :visits, dependent: :destroy
  has_many :email_deduplication_logs, dependent: :destroy
  
  validates :wix_user_id, presence: true, uniqueness: true
  
  # Normalize plan names from frontend
  before_validation :normalize_subscription_plan
  
  scope :active, -> { where(active: true) }
  scope :with_jobber, -> { where.not(jobber_account_id: nil) }
  
  def can_send_email?
    emails_sent_this_period < email_limit
  end
  
  def increment_email_count!
    increment!(:emails_sent_this_period)
  end
  
  def reset_billing_period!
    update!(
      emails_sent_this_period: 0,
      billing_period_start: Time.current,
      billing_period_end: 1.month.from_now
    )
  end
  
  def purge_old_data!
    cutoff_date = retention_days.days.ago
    visits.where('created_at < ?', cutoff_date).destroy_all
    email_deduplication_logs.where('created_at < ?', cutoff_date).destroy_all
  end
  
  # Get display name for frontend
  def display_plan_name
    case subscription_plan
    when 'basic' then 'Startup'
    when 'pro' then 'Growth'
    when 'enterprise' then 'Elite'
    else subscription_plan.capitalize
    end
  end
  
  private
  
  def normalize_subscription_plan
    if subscription_plan.present?
      self.subscription_plan = PLAN_MAPPING[subscription_plan] || subscription_plan
    end
  end
end