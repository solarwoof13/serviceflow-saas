# app/models/email_deduplication_log.rb
class EmailDeduplicationLog < ApplicationRecord
  validates :visit_id, presence: true
  validates :customer_email, presence: true
  
  scope :for_visit, ->(visit_id) { where(visit_id: visit_id) }
  scope :sent_emails, -> { where(email_status: 'sent') }
  scope :recent, -> { where('created_at > ?', 24.hours.ago) }
  
  def self.already_sent_for_visit?(visit_id, customer_email)
    sent_emails
      .where(visit_id: visit_id, customer_email: customer_email)
      .where('created_at > ?', 24.hours.ago) # Only check last 24 hours
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