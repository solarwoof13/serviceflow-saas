# app/models/subscription_feature.rb
class SubscriptionFeature < ApplicationRecord
  belongs_to :subscription
  belongs_to :feature
end
