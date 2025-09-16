class Email < ApplicationRecord
  belongs_to :wix_user
  belongs_to :jobber_account, optional: true  # Add this
  
  # Add validations only if columns exist
  validates :recipient_email, presence: true, if: -> { has_attribute?(:recipient_email) }
  
  scope :sent, -> { where(status: 'sent') }, if: -> { has_attribute?(:status) }
  scope :failed, -> { where(status: 'failed') }, if: -> { has_attribute?(:status) }
  scope :recent, -> { where('sent_at > ?', 7.days.ago) }, if: -> { has_attribute?(:sent_at) }
end