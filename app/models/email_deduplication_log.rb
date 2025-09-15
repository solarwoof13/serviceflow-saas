class EmailDeduplicationLog < ApplicationRecord
  belongs_to :jobber_account, optional: true  # Add association
  
  validates :job_id, presence: true  # Change from visit_id
  validates :customer_email, presence: true
  
  scope :for_visit, ->(visit_id) { where(visit_id: visit_id) }
  scope :sent, -> { where(email_status: 'sent') }  # Rename from sent_emails
  scope :recent, -> { where('created_at > ?', 24.hours.ago) }  # Keep 24 hours
  
  def self.already_sent_for_visit?(visit_id, customer_email)
    sent
      .where(visit_id: visit_id, customer_email: customer_email)
      .where('created_at > ?', 24.hours.ago)
      .exists?
  end
  
  def self.log_email_attempt(visit_id:, job_id:, customer_email:, webhook_topic:, webhook_data:, status:, block_reason: nil)
    create!(
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
  
  def self.cleanup_old_logs
    # Keep logs for 7 days, then clean up
    where('created_at < ?', 7.days.ago).delete_all
  end
end