class Email < ApplicationRecord
  belongs_to :wix_user, optional: true
  belongs_to :jobber_account, optional: true
  belongs_to :visit, optional: true
  
  validates :recipient_email, presence: true
  
  # Fix these scopes - only 2 arguments allowed
  scope :sent, -> { where(status: 'sent') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { where('sent_at > ?', 7.days.ago) }
end