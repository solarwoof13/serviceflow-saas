class WixUser < ApplicationRecord
  # Connect to ServiceProviderProfile and JobberAccount
  has_one :service_provider_profile, foreign_key: :wix_user_id
  has_one :jobber_account, through: :service_provider_profile
  
  validates :wix_member_id, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  # Generate API token for Wix authentication
  before_create :generate_api_token
  
  def generate_api_token
    self.api_token = SecureRandom.urlsafe_base64(32)
  end
  
  def subscription_active?
    return true if subscription_level == 'PAID'
    return trial_days_remaining > 0 if subscription_level == 'FREE'
    false
  end
  
  def trial_expired?
    subscription_level == 'FREE' && trial_days_remaining <= 0
  end
end

# Create database migration
# rails generate migration CreateWixUsers

class CreateWixUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :wix_users do |t|
      t.string :wix_member_id, null: false, index: { unique: true }
      t.string :email, null: false
      t.string :company_name
      t.string :subscription_level, default: 'FREE'
      t.integer :trial_days_remaining, default: 14
      t.string :api_token, index: { unique: true }
      t.boolean :profile_completed, default: false
      t.datetime :last_login
      t.datetime :last_sync
      t.json :metadata

      t.timestamps
    end
  end
end
