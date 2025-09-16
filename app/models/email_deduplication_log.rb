class EmailDeduplicationLog < ApplicationRecord
  belongs_to :wix_user, optional: true
  belongs_to :jobber_account, optional: true
  
  validates :job_id, presence: true
  validates :customer_email, presence: true
  
  scope :for_visit, ->(visit_id) { where(visit_id: visit_id) }
  scope :sent, -> { where(email_status: 'sent') }
  scope :recent, -> { where('created_at > ?', 24.hours.ago) }
  
  # Check limits before sending
  before_create :check_email_limits
  
  def self.already_sent_for_visit?(visit_id, customer_email)
    sent
      .where(visit_id: visit_id, customer_email: customer_email)
      .where('created_at > ?', 24.hours.ago)
      .exists?
  end
  
  def self.log_email_attempt(wix_user:, visit_id:, job_id:, customer_email:, webhook_topic:, webhook_data:, status:, block_reason: nil)
    create!(
      wix_user: wix_user,
      jobber_account: wix_user.jobber_account,
      visit_id: visit_id,
      job_id: job_id,
      customer_email: customer_email,
      webhook_topic: webhook_topic,
      webhook_data: webhook_data,
      email_status: status,
      block_reason: block_reason,
      email_sent_at: (status == 'sent' ? Time.current : nil)
    )
  end
  
  private
  
  def check_email_limits
    if wix_user && !wix_user.can_send_email?
      errors.add(:base, "Email limit reached for subscription plan")
      throw :abort
    end
  end
end