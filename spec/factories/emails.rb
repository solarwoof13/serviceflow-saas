FactoryBot.define do
  factory :email do
    subject { "MyString" }
    content { "MyText" }
    wix_user { nil }
    sent_at { "2025-09-03 15:54:42" }
  end
end
