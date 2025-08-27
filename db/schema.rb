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

ActiveRecord::Schema[7.2].define(version: 2025_08_27_155504) do
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

  create_table "jobber_accounts", force: :cascade do |t|
    t.string "jobber_id"
    t.string "name"
    t.string "jobber_access_token"
    t.datetime "jobber_access_token_expired_by", precision: nil
    t.string "jobber_refresh_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.boolean "needs_reauthorization", default: false
    t.string "account_id"
    t.index ["account_id"], name: "index_jobber_accounts_on_account_id", unique: true
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

  add_foreign_key "service_provider_profiles", "jobber_accounts"
end
