# app/models/subscription.rb
class Subscription < ApplicationRecord
  belongs_to :wix_user
  has_many :subscription_features
  has_many :features, through: :subscription_features
  
  enum level: { startup: 0, growth: 1, elite: 2 }
  validates :level, presence: true
end