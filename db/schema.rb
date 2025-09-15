# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_09_15_161405) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "email_deduplication_logs", force: :cascade do |t|
    t.string "visit_id", null: false
    t.string "job_id"
    t.string "customer_email", null: false
    t.string "webhook_topic"
    t.json "webhook_data"
    t.string "email_status"
    t.string "block_reason"
    t.datetime "email_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_email_deduplication_logs_on_created_at"
    t.index ["job_id"], name: "index_email_deduplication_logs_on_job_id"
    t.index ["visit_id", "customer_email"], name: "idx_dedup_visit_customer"
    t.index ["visit_id"], name: "index_email_deduplication_logs_on_visit_id"
  end

  create_table "emails", force: :cascade do |t|
    t.string "subject"
    t.text "content"
    t.bigint "wix_user_id", null: false
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recipient_email"
    t.string "status"
    t.bigint "jobber_account_id"
    t.bigint "visit_id"
    t.index ["jobber_account_id"], name: "index_emails_on_jobber_account_id"
    t.index ["visit_id"], name: "index_emails_on_visit_id"
    t.index ["wix_user_id"], name: "index_emails_on_wix_user_id"
  end

  create_table "features", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_features_on_name"
  end

  create_table "jobber_accounts", force: :cascade do |t|
    t.string "jobber_id"
    t.string "name"
    t.string "jobber_access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.boolean "needs_reauthorization", default: false
    t.jsonb "processed_visit_ids"
    t.index ["jobber_id"], name: "index_jobber_accounts_on_jobber_id", unique: true
  end

  create_table "service_provider_profiles", force: :cascade do |t|
    t.bigint "jobber_account_id", null: false
    t.string "company_name", null: false
    t.text "company_description"
    t.string "years_in_business"
    t.jsonb "service_areas", default: []
    t.string "main_service_type"
    t.text "service_details"
    t.text "equipment_methods"
    t.text "unique_selling_points"
    t.string "certifications_licenses"
    t.text "local_expertise"
    t.text "spring_services"
    t.text "summer_services"
    t.text "fall_services"
    t.text "winter_services"
    t.string "email_tone", default: "professional"
    t.text "always_include"
    t.text "never_mention"
    t.boolean "profile_completed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jobber_account_id"], name: "idx_spp_jobber_account"
    t.index ["jobber_account_id"], name: "index_service_provider_profiles_on_jobber_account_id"
    t.index ["main_service_type"], name: "idx_spp_service_type"
    t.index ["service_areas"], name: "idx_spp_service_areas", using: :gin
  end

  create_table "subscription_features", force: :cascade do |t|
    t.bigint "subscription_id", null: false
    t.bigint "feature_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_id"], name: "index_subscription_features_on_feature_id"
    t.index ["subscription_id"], name: "index_subscription_features_on_subscription_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "wix_user_id", null: false
    t.integer "level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["wix_user_id"], name: "index_subscriptions_on_wix_user_id"
  end

  create_table "visits", force: :cascade do |t|
    t.string "title"
    t.text "notes"
    t.bigint "wix_user_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "jobber_visit_id"
    t.datetime "data_expires_at"
    t.bigint "jobber_account_id"
    t.index ["jobber_account_id"], name: "index_visits_on_jobber_account_id"
    t.index ["wix_user_id"], name: "index_visits_on_wix_user_id"
  end

  create_table "webhook_events", force: :cascade do |t|
    t.string "event_type", null: false
    t.string "jobber_item_id"
    t.jsonb "payload", default: {}
    t.string "processing_status", default: "pending"
    t.text "error_message"
    t.bigint "jobber_account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_webhook_events_on_created_at"
    t.index ["event_type", "created_at"], name: "index_webhook_events_on_event_type_and_created_at"
    t.index ["jobber_account_id"], name: "index_webhook_events_on_jobber_account_id"
    t.index ["jobber_item_id"], name: "index_webhook_events_on_jobber_item_id"
    t.index ["processing_status"], name: "index_webhook_events_on_processing_status"
  end

  create_table "wix_users", force: :cascade do |t|
    t.string "wix_id"
    t.string "email"
    t.jsonb "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["wix_id"], name: "index_wix_users_on_wix_id"
  end

  add_foreign_key "emails", "wix_users"
  add_foreign_key "service_provider_profiles", "jobber_accounts"
  add_foreign_key "subscription_features", "features"
  add_foreign_key "subscription_features", "subscriptions"
  add_foreign_key "subscriptions", "wix_users"
  add_foreign_key "visits", "wix_users"
  add_foreign_key "webhook_events", "jobber_accounts"
end
