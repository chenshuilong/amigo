# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180412025720) do

  create_table "alter_record_details", force: :cascade do |t|
    t.integer  "alter_record_id", limit: 4
    t.string   "property",        limit: 255
    t.string   "prop_key",        limit: 255
    t.text     "old_value",       limit: 65535
    t.text     "value",           limit: 65535
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  create_table "alter_records", force: :cascade do |t|
    t.integer  "alter_for_id",   limit: 4
    t.string   "alter_for_type", limit: 255
    t.integer  "user_id",        limit: 4
    t.text     "notes",          limit: 65535
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "apk_bases", force: :cascade do |t|
    t.string   "name",             limit: 255
    t.string   "cn_name",          limit: 255
    t.string   "en_name",          limit: 255
    t.text     "cn_description",   limit: 65535
    t.text     "en_description",   limit: 65535
    t.string   "desktop_name",     limit: 255
    t.boolean  "desktop_icon"
    t.string   "developer",        limit: 255
    t.string   "package_name",     limit: 255
    t.integer  "category_id",      limit: 4
    t.string   "removable",        limit: 255
    t.integer  "os_category",      limit: 4
    t.integer  "app_category",     limit: 4
    t.integer  "author_id",        limit: 4,     null: false
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.text     "notes",            limit: 65535
    t.integer  "android_platform", limit: 4
    t.boolean  "integrated"
  end

  create_table "apprelease", force: :cascade do |t|
    t.float  "appid",                 limit: 53
    t.string "app_name",              limit: 765
    t.string "spec_version",          limit: 765
    t.string "created_on",            limit: 765
    t.string "file_name",             limit: 765
    t.float  "category",              limit: 53
    t.string "version_applicable_to", limit: 765
    t.string "tested_mobile",         limit: 765
    t.string "test_type",             limit: 765
    t.string "test_finished_on",      limit: 765
    t.float  "codes_reviewed",        limit: 53
    t.float  "cases_sync_updated",    limit: 53
    t.float  "code_walkthrough_well", limit: 53
    t.string "mode",                  limit: 27
    t.string "author_id",             limit: 270
    t.float  "cts_test",              limit: 53
    t.float  "relative_objects",      limit: 53
    t.string "new_issues",            limit: 765
    t.string "remaining_issues",      limit: 765
    t.string "created_at",            limit: 765
    t.string "note",                  limit: 765
    t.binary "path",                  limit: 65535
    t.binary "note_one",              limit: 65535
    t.binary "note_two",              limit: 65535
    t.string "server_version",        limit: 765
    t.string "validation_results",    limit: 765
    t.string "other_app",             limit: 765
    t.string "is_sqa",                limit: 9
    t.string "is_ued",                limit: 9
  end

  create_table "approvals", force: :cascade do |t|
    t.string   "type",        limit: 255
    t.string   "object_type", limit: 255
    t.integer  "object_id",   limit: 4
    t.integer  "user_id",     limit: 4
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "approvals", ["user_id"], name: "index_approvals_on_user_id", using: :btree

  create_table "attachments", force: :cascade do |t|
    t.integer  "container_id",   limit: 4
    t.string   "container_type", limit: 30
    t.string   "filename",       limit: 255, default: "", null: false
    t.string   "disk_filename",  limit: 255, default: "", null: false
    t.integer  "filesize",       limit: 8,   default: 0,  null: false
    t.string   "content_type",   limit: 255, default: ""
    t.string   "digest",         limit: 40,  default: "", null: false
    t.integer  "downloads",      limit: 4,   default: 0,  null: false
    t.integer  "author_id",      limit: 4,   default: 0,  null: false
    t.datetime "created_on"
    t.string   "description",    limit: 255
    t.string   "disk_directory", limit: 255
    t.string   "uniq_key",       limit: 255
    t.string   "ftp_ip",         limit: 255
    t.string   "extra_type",     limit: 255
  end

  add_index "attachments", ["author_id"], name: "index_attachments_on_author_id", using: :btree
  add_index "attachments", ["container_id", "container_type"], name: "index_attachments_on_container_id_and_container_type", using: :btree
  add_index "attachments", ["created_on"], name: "index_attachments_on_created_on", using: :btree

  create_table "auth_sources", force: :cascade do |t|
    t.string  "type",              limit: 30,    default: "",    null: false
    t.string  "name",              limit: 60,    default: "",    null: false
    t.string  "host",              limit: 60
    t.integer "port",              limit: 4
    t.string  "account",           limit: 255
    t.string  "account_password",  limit: 255,   default: ""
    t.string  "base_dn",           limit: 255
    t.string  "attr_login",        limit: 30
    t.string  "attr_firstname",    limit: 30
    t.string  "attr_lastname",     limit: 30
    t.string  "attr_mail",         limit: 30
    t.boolean "onthefly_register",               default: false, null: false
    t.boolean "tls",                             default: false, null: false
    t.text    "filter",            limit: 65535
    t.integer "timeout",           limit: 4
  end

  add_index "auth_sources", ["id", "type"], name: "index_auth_sources_on_id_and_type", using: :btree

  create_table "boards", force: :cascade do |t|
    t.integer "project_id",      limit: 4,                null: false
    t.string  "name",            limit: 255, default: "", null: false
    t.string  "description",     limit: 255
    t.integer "position",        limit: 4
    t.integer "topics_count",    limit: 4,   default: 0,  null: false
    t.integer "messages_count",  limit: 4,   default: 0,  null: false
    t.integer "last_message_id", limit: 4
    t.integer "parent_id",       limit: 4
  end

  add_index "boards", ["last_message_id"], name: "index_boards_on_last_message_id", using: :btree
  add_index "boards", ["project_id"], name: "boards_project_id", using: :btree

  create_table "changes", force: :cascade do |t|
    t.integer "changeset_id",  limit: 4,                  null: false
    t.string  "action",        limit: 1,     default: "", null: false
    t.text    "path",          limit: 65535,              null: false
    t.text    "from_path",     limit: 65535
    t.string  "from_revision", limit: 255
    t.string  "revision",      limit: 255
    t.string  "branch",        limit: 255
  end

  add_index "changes", ["changeset_id"], name: "changesets_changeset_id", using: :btree

  create_table "changeset_parents", id: false, force: :cascade do |t|
    t.integer "changeset_id", limit: 4, null: false
    t.integer "parent_id",    limit: 4, null: false
  end

  add_index "changeset_parents", ["changeset_id"], name: "changeset_parents_changeset_ids", using: :btree
  add_index "changeset_parents", ["parent_id"], name: "changeset_parents_parent_ids", using: :btree

  create_table "changesets", force: :cascade do |t|
    t.integer  "repository_id", limit: 4,          null: false
    t.string   "revision",      limit: 255,        null: false
    t.string   "committer",     limit: 255
    t.datetime "committed_on",                     null: false
    t.text     "comments",      limit: 4294967295
    t.date     "commit_date"
    t.string   "scmid",         limit: 255
    t.integer  "user_id",       limit: 4
  end

  add_index "changesets", ["committed_on"], name: "index_changesets_on_committed_on", using: :btree
  add_index "changesets", ["repository_id", "revision"], name: "changesets_repos_rev", unique: true, using: :btree
  add_index "changesets", ["repository_id", "scmid"], name: "changesets_repos_scmid", using: :btree
  add_index "changesets", ["repository_id"], name: "index_changesets_on_repository_id", using: :btree
  add_index "changesets", ["user_id"], name: "index_changesets_on_user_id", using: :btree

  create_table "changesets_issues", id: false, force: :cascade do |t|
    t.integer "changeset_id", limit: 4, null: false
    t.integer "issue_id",     limit: 4, null: false
  end

  add_index "changesets_issues", ["changeset_id", "issue_id"], name: "changesets_issues_ids", unique: true, using: :btree

  create_table "comments", force: :cascade do |t|
    t.string   "commented_type", limit: 30,    default: "", null: false
    t.integer  "commented_id",   limit: 4,     default: 0,  null: false
    t.integer  "author_id",      limit: 4,     default: 0,  null: false
    t.text     "comments",       limit: 65535
    t.datetime "created_on",                                null: false
    t.datetime "updated_on",                                null: false
  end

  add_index "comments", ["author_id"], name: "index_comments_on_author_id", using: :btree
  add_index "comments", ["commented_id", "commented_type"], name: "index_comments_on_commented_id_and_commented_type", using: :btree

  create_table "competitive_goods", force: :cascade do |t|
    t.integer  "user_id",    limit: 4
    t.text     "name",       limit: 65535
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  create_table "condition_histories", force: :cascade do |t|
    t.integer  "from_id",    limit: 4
    t.integer  "user_id",    limit: 4
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "condition_histories", ["user_id"], name: "index_condition_histories_on_user_id", using: :btree

  create_table "conditions", force: :cascade do |t|
    t.integer  "category",     limit: 4,     default: 1
    t.string   "name",         limit: 255
    t.boolean  "is_folder",                  default: false
    t.integer  "folder_id",    limit: 4
    t.integer  "user_id",      limit: 4
    t.text     "condition",    limit: 65535
    t.text     "column_order", limit: 65535
    t.integer  "project_id",   limit: 4
    t.text     "json",         limit: 65535
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  add_index "conditions", ["folder_id"], name: "index_on_folder_id", using: :btree
  add_index "conditions", ["user_id"], name: "index_conditions_on_user_id", using: :btree

  create_table "criterion_secondaries", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "sort",       limit: 255
    t.string   "target",     limit: 255
    t.integer  "parent_id",  limit: 4
    t.boolean  "active",                 default: true
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
  end

  create_table "criterions", force: :cascade do |t|
    t.string   "name",        limit: 255
    t.string   "identifier",  limit: 255
    t.text     "purpose",     limit: 65535
    t.text     "description", limit: 65535
    t.text     "dept_range",  limit: 65535
    t.string   "output_time", limit: 255
    t.text     "settings",    limit: 65535
    t.boolean  "active",                    default: true
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
  end

  create_table "custom_field_enumerations", force: :cascade do |t|
    t.integer "custom_field_id", limit: 4,                  null: false
    t.string  "name",            limit: 255,                null: false
    t.boolean "active",                      default: true, null: false
    t.integer "position",        limit: 4,   default: 1,    null: false
  end

  create_table "custom_fields", force: :cascade do |t|
    t.string  "type",            limit: 30,    default: "",    null: false
    t.string  "name",            limit: 30,    default: "",    null: false
    t.string  "field_format",    limit: 30,    default: "",    null: false
    t.text    "possible_values", limit: 65535
    t.string  "regexp",          limit: 255,   default: ""
    t.integer "min_length",      limit: 4
    t.integer "max_length",      limit: 4
    t.boolean "is_required",                   default: false, null: false
    t.boolean "is_for_all",                    default: false, null: false
    t.boolean "is_filter",                     default: false, null: false
    t.integer "position",        limit: 4
    t.boolean "searchable",                    default: false
    t.text    "default_value",   limit: 65535
    t.boolean "editable",                      default: true
    t.boolean "visible",                       default: true,  null: false
    t.boolean "multiple",                      default: false
    t.text    "format_store",    limit: 65535
    t.text    "description",     limit: 65535
  end

  add_index "custom_fields", ["id", "type"], name: "index_custom_fields_on_id_and_type", using: :btree

  create_table "custom_fields_projects", id: false, force: :cascade do |t|
    t.integer "custom_field_id", limit: 4, default: 0, null: false
    t.integer "project_id",      limit: 4, default: 0, null: false
  end

  add_index "custom_fields_projects", ["custom_field_id", "project_id"], name: "index_custom_fields_projects_on_custom_field_id_and_project_id", unique: true, using: :btree

  create_table "custom_fields_roles", id: false, force: :cascade do |t|
    t.integer "custom_field_id", limit: 4, null: false
    t.integer "role_id",         limit: 4, null: false
  end

  add_index "custom_fields_roles", ["custom_field_id", "role_id"], name: "custom_fields_roles_ids", unique: true, using: :btree

  create_table "custom_fields_trackers", id: false, force: :cascade do |t|
    t.integer "custom_field_id", limit: 4, default: 0, null: false
    t.integer "tracker_id",      limit: 4, default: 0, null: false
  end

  add_index "custom_fields_trackers", ["custom_field_id", "tracker_id"], name: "index_custom_fields_trackers_on_custom_field_id_and_tracker_id", unique: true, using: :btree

  create_table "custom_permissions", force: :cascade do |t|
    t.integer  "user_id",         limit: 4
    t.string   "permission_type", limit: 255
    t.integer  "author_id",       limit: 4
    t.text     "notes",           limit: 65535
    t.boolean  "locked",                        default: false
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
  end

  add_index "custom_permissions", ["user_id"], name: "index_custom_permissions_on_user_id", using: :btree

  create_table "custom_values", force: :cascade do |t|
    t.string  "customized_type", limit: 30,    default: "", null: false
    t.integer "customized_id",   limit: 4,     default: 0,  null: false
    t.integer "custom_field_id", limit: 4,     default: 0,  null: false
    t.text    "value",           limit: 65535
  end

  add_index "custom_values", ["custom_field_id"], name: "index_custom_values_on_custom_field_id", using: :btree
  add_index "custom_values", ["customized_id", "custom_field_id", "customized_type"], name: "index_custom_fields_for_joins", using: :btree
  add_index "custom_values", ["customized_type", "customized_id"], name: "custom_values_customized", using: :btree

  create_table "default_values", force: :cascade do |t|
    t.string   "category",   limit: 255
    t.integer  "user_id",    limit: 4
    t.string   "name",       limit: 255
    t.text     "json",       limit: 65535
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "default_values", ["user_id"], name: "index_default_values_on_user_id", using: :btree

  create_table "definition_alter_records", force: :cascade do |t|
    t.integer  "definition_id",      limit: 4
    t.integer  "user_id",            limit: 4
    t.integer  "record_type",        limit: 4
    t.string   "prop_key",           limit: 255
    t.text     "old_value",          limit: 65535
    t.text     "value",              limit: 65535
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.string   "definition_version", limit: 255
  end

  create_table "definition_custom_values", force: :cascade do |t|
    t.integer  "definition_id",         limit: 4
    t.integer  "definition_section_id", limit: 4
    t.integer  "custom_field_id",       limit: 4
    t.text     "value",                 limit: 65535
    t.boolean  "display",                             default: true
    t.integer  "sort",                  limit: 4
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
  end

  add_index "definition_custom_values", ["definition_id", "definition_section_id", "custom_field_id"], name: "idx_on_definition_section_field", using: :btree

  create_table "definition_sections", force: :cascade do |t|
    t.text     "name",       limit: 65535
    t.integer  "parent_id",  limit: 4
    t.integer  "author_id",  limit: 4
    t.boolean  "display",                  default: true
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
  end

  create_table "definition_sections_custom_fields", force: :cascade do |t|
    t.integer "definition_section_id", limit: 4
    t.integer "custom_field_id",       limit: 4
    t.integer "sort",                  limit: 4
  end

  create_table "definitions", force: :cascade do |t|
    t.integer  "project_id",              limit: 4
    t.text     "internal_version_desc",   limit: 65535
    t.text     "mobile_public_cta",       limit: 65535
    t.text     "mobile_public_cta_desc",  limit: 65535
    t.text     "propaganda_version",      limit: 65535
    t.text     "propaganda_version_desc", limit: 65535
    t.text     "product_position",        limit: 65535
    t.text     "product_position_desc",   limit: 65535
    t.text     "product_series",          limit: 65535
    t.text     "product_series_desc",     limit: 65535
    t.text     "selling_point",           limit: 65535
    t.text     "selling_point_desc",      limit: 65535
    t.text     "target_population",       limit: 65535
    t.text     "target_population_desc",  limit: 65535
    t.datetime "product_dt"
    t.text     "product_dt_desc",         limit: 65535
    t.text     "production_version",      limit: 65535
    t.text     "production_version_desc", limit: 65535
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
  end

  create_table "demands", force: :cascade do |t|
    t.integer  "category_id",     limit: 4
    t.integer  "sub_category_id", limit: 4
    t.integer  "status",          limit: 4
    t.text     "description",     limit: 65535
    t.text     "method",          limit: 65535
    t.string   "related_ids",     limit: 255
    t.text     "related_notes",   limit: 65535
    t.integer  "author_id",       limit: 4
    t.date     "feedback_at"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  create_table "depts", force: :cascade do |t|
    t.string   "orgNm",                  limit: 255
    t.string   "orgNo",                  limit: 255
    t.string   "parentNo",               limit: 255
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
    t.integer  "createBy",               limit: 4
    t.integer  "leve",                   limit: 4
    t.datetime "lastDate"
    t.integer  "lastUpd",                limit: 4
    t.string   "otype",                  limit: 10
    t.datetime "staDate"
    t.integer  "oveDate",                limit: 4
    t.integer  "status",                 limit: 4
    t.text     "remark",                 limit: 65535
    t.integer  "manager_id",             limit: 4
    t.integer  "sub_manager_id",         limit: 4
    t.integer  "supervisor_id",          limit: 4
    t.integer  "majordomo_id",           limit: 4
    t.integer  "vice_president_id",      limit: 4
    t.string   "comNm",                  limit: 255
    t.string   "parentNm",               limit: 255
    t.string   "manager_number",         limit: 255
    t.string   "manager_name",           limit: 255
    t.string   "manager2_number",        limit: 255
    t.string   "manager2_name",          limit: 255
    t.string   "sub_manager_number",     limit: 255
    t.string   "sub_manager_name",       limit: 255
    t.string   "sub_manager2_number",    limit: 255
    t.string   "sub_manager2_name",      limit: 255
    t.string   "supervisor_number",      limit: 255
    t.string   "supervisor_name",        limit: 255
    t.string   "supervisor2_number",     limit: 255
    t.string   "supervisor2_name",       limit: 255
    t.string   "majordomo_number",       limit: 255
    t.string   "majordomo_name",         limit: 255
    t.string   "sub_majordomo_number",   limit: 255
    t.string   "sub_majordomo_name",     limit: 255
    t.string   "vice_president_number",  limit: 255
    t.string   "vice_president_name",    limit: 255
    t.string   "vice_president2_number", limit: 255
    t.string   "vice_president2_name",   limit: 255
  end

  add_index "depts", ["orgNo"], name: "index_depts_on_orgNo", using: :btree

  create_table "document_attachments", force: :cascade do |t|
    t.integer  "document_id",   limit: 4
    t.string   "category_id",   limit: 255
    t.string   "attachment_id", limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  create_table "documents", force: :cascade do |t|
    t.integer  "project_id",  limit: 4,     default: 0,  null: false
    t.integer  "category_id", limit: 4,     default: 0,  null: false
    t.string   "title",       limit: 255,   default: "", null: false
    t.text     "description", limit: 65535
    t.datetime "created_on"
  end

  add_index "documents", ["category_id"], name: "index_documents_on_category_id", using: :btree
  add_index "documents", ["created_on"], name: "index_documents_on_created_on", using: :btree
  add_index "documents", ["project_id"], name: "documents_project_id", using: :btree

  create_table "email_addresses", force: :cascade do |t|
    t.integer  "user_id",    limit: 4,                   null: false
    t.string   "address",    limit: 255,                 null: false
    t.boolean  "is_default",             default: false, null: false
    t.boolean  "notify",                 default: true,  null: false
    t.datetime "created_on",                             null: false
    t.datetime "updated_on",                             null: false
  end

  add_index "email_addresses", ["user_id"], name: "index_email_addresses_on_user_id", using: :btree

  create_table "enabled_modules", force: :cascade do |t|
    t.integer "project_id", limit: 4
    t.string  "name",       limit: 255, null: false
  end

  add_index "enabled_modules", ["name"], name: "idx_on_name", using: :btree
  add_index "enabled_modules", ["project_id"], name: "enabled_modules_project_id", using: :btree

  create_table "enumerations", force: :cascade do |t|
    t.string  "name",          limit: 30,  default: "",    null: false
    t.integer "position",      limit: 4
    t.boolean "is_default",                default: false, null: false
    t.string  "type",          limit: 255
    t.boolean "active",                    default: true,  null: false
    t.integer "project_id",    limit: 4
    t.integer "parent_id",     limit: 4
    t.string  "position_name", limit: 30
  end

  add_index "enumerations", ["id", "type"], name: "index_enumerations_on_id_and_type", using: :btree
  add_index "enumerations", ["project_id"], name: "index_enumerations_on_project_id", using: :btree

  create_table "exports", force: :cascade do |t|
    t.integer  "category",   limit: 4
    t.string   "name",       limit: 255
    t.integer  "status",     limit: 4
    t.text     "sql",        limit: 65535
    t.text     "options",    limit: 65535
    t.string   "disk_file",  limit: 255
    t.string   "format",     limit: 255
    t.string   "file_size",  limit: 255
    t.integer  "lines",      limit: 4
    t.integer  "total_time", limit: 4
    t.integer  "user_id",    limit: 4
    t.boolean  "deleted",                  default: false
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
  end

  create_table "google_tools", force: :cascade do |t|
    t.integer  "category",        limit: 4
    t.string   "android_version", limit: 255
    t.string   "tool_version",    limit: 255
    t.text     "tool_url",        limit: 65535
    t.text     "notes",           limit: 65535
    t.datetime "closed_at"
    t.integer  "author_id",       limit: 4
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  add_index "google_tools", ["author_id"], name: "index_google_tools_on_author_id", using: :btree

  create_table "groups_users", id: false, force: :cascade do |t|
    t.integer "group_id", limit: 4, null: false
    t.integer "user_id",  limit: 4, null: false
  end

  add_index "groups_users", ["group_id", "user_id"], name: "groups_users_ids", unique: true, using: :btree

  create_table "import_items", force: :cascade do |t|
    t.integer "import_id", limit: 4,     null: false
    t.integer "position",  limit: 4,     null: false
    t.integer "obj_id",    limit: 4
    t.text    "message",   limit: 65535
  end

  create_table "imports", force: :cascade do |t|
    t.string   "type",        limit: 255
    t.integer  "user_id",     limit: 4,                     null: false
    t.string   "filename",    limit: 255
    t.text     "settings",    limit: 65535
    t.integer  "total_items", limit: 4
    t.boolean  "finished",                  default: false, null: false
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
  end

  create_table "issue_categories", force: :cascade do |t|
    t.integer "project_id",     limit: 4,  default: 0,  null: false
    t.string  "name",           limit: 60, default: "", null: false
    t.integer "assigned_to_id", limit: 4
  end

  add_index "issue_categories", ["assigned_to_id"], name: "index_issue_categories_on_assigned_to_id", using: :btree
  add_index "issue_categories", ["project_id"], name: "issue_categories_project_id", using: :btree

  create_table "issue_gerrits", force: :cascade do |t|
    t.integer  "issue_id",   limit: 4
    t.integer  "user_id",    limit: 4
    t.string   "message",    limit: 255
    t.string   "link",       limit: 255
    t.string   "repository", limit: 255
    t.string   "branch",     limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "issue_gerrits", ["issue_id"], name: "index_issue_gerrits_on_issue_id", using: :btree
  add_index "issue_gerrits", ["user_id"], name: "index_issue_gerrits_on_user_id", using: :btree

  create_table "issue_histories", force: :cascade do |t|
    t.datetime "date"
    t.integer  "issue_id",       limit: 4
    t.integer  "status_id",      limit: 4
    t.integer  "assigned_to_id", limit: 4
    t.integer  "project_id",     limit: 4
    t.integer  "priority_id",    limit: 4
    t.string   "probability_id", limit: 255
    t.integer  "mokuai_name",    limit: 4
  end

  create_table "issue_relations", force: :cascade do |t|
    t.integer "issue_from_id", limit: 4,                null: false
    t.integer "issue_to_id",   limit: 4,                null: false
    t.string  "relation_type", limit: 255, default: "", null: false
    t.integer "delay",         limit: 4
  end

  add_index "issue_relations", ["issue_from_id", "issue_to_id"], name: "index_issue_relations_on_issue_from_id_and_issue_to_id", unique: true, using: :btree
  add_index "issue_relations", ["issue_from_id"], name: "index_issue_relations_on_issue_from_id", using: :btree
  add_index "issue_relations", ["issue_to_id"], name: "index_issue_relations_on_issue_to_id", using: :btree

  create_table "issue_statuses", force: :cascade do |t|
    t.string  "name",               limit: 30, default: "",    null: false
    t.boolean "is_closed",                     default: false, null: false
    t.integer "position",           limit: 4
    t.integer "default_done_ratio", limit: 4
  end

  add_index "issue_statuses", ["is_closed"], name: "index_issue_statuses_on_is_closed", using: :btree
  add_index "issue_statuses", ["position"], name: "index_issue_statuses_on_position", using: :btree

  create_table "issue_to_approve_merges", force: :cascade do |t|
    t.string   "issue_type",         limit: 255
    t.integer  "issue_id",           limit: 4
    t.string   "commit_id",          limit: 255
    t.text     "branche_ids",        limit: 65535
    t.text     "related_issue_ids",  limit: 65535
    t.text     "related_apks",       limit: 65535
    t.text     "tester_advice",      limit: 65535
    t.text     "dept_result",        limit: 65535
    t.text     "project_result",     limit: 65535
    t.text     "master_version_id",  limit: 65535
    t.text     "branch_version_ids", limit: 65535
    t.text     "reason",             limit: 65535
    t.text     "requirement",        limit: 65535
    t.text     "notes",              limit: 65535
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.text     "repo_request_ids",   limit: 65535
  end

  add_index "issue_to_approve_merges", ["issue_id"], name: "index_issue_to_approve_merges_on_issue_id", using: :btree

  create_table "issue_to_special_test_results", force: :cascade do |t|
    t.integer  "special_test_id", limit: 4
    t.integer  "designer_id",     limit: 4
    t.integer  "assigned_to_id",  limit: 4
    t.text     "steps",           limit: 65535
    t.string   "sample_num",      limit: 255
    t.string   "catch_log_way",   limit: 255
    t.integer  "result",          limit: 4
    t.text     "notes",           limit: 65535
    t.datetime "start_date"
    t.datetime "due_date"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  create_table "issue_to_special_tests", force: :cascade do |t|
    t.integer  "project_id",      limit: 4
    t.integer  "category",        limit: 4
    t.string   "subject",         limit: 255
    t.integer  "status",          limit: 4
    t.string   "related_issues",  limit: 255
    t.string   "test_times",      limit: 255
    t.boolean  "log_from_com"
    t.string   "machine_num",     limit: 255
    t.text     "test_method",     limit: 65535
    t.text     "attentions",      limit: 65535
    t.string   "test_version",    limit: 255
    t.integer  "priority",        limit: 4
    t.text     "approval_result", limit: 65535
    t.integer  "author_id",       limit: 4
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.text     "precondition",    limit: 65535
  end

  create_table "issues", force: :cascade do |t|
    t.integer  "tracker_id",             limit: 4,                     null: false
    t.integer  "project_id",             limit: 4,                     null: false
    t.string   "subject",                limit: 255,   default: "",    null: false
    t.text     "description",            limit: 65535
    t.date     "due_date"
    t.integer  "category_id",            limit: 4
    t.integer  "status_id",              limit: 4,                     null: false
    t.integer  "assigned_to_id",         limit: 4
    t.integer  "priority_id",            limit: 4,                     null: false
    t.integer  "fixed_version_id",       limit: 4
    t.integer  "author_id",              limit: 4,                     null: false
    t.integer  "lock_version",           limit: 4,     default: 0,     null: false
    t.datetime "created_on"
    t.datetime "updated_on"
    t.date     "start_date"
    t.integer  "done_ratio",             limit: 4,     default: 0,     null: false
    t.float    "estimated_hours",        limit: 24
    t.integer  "parent_id",              limit: 4
    t.integer  "root_id",                limit: 4
    t.integer  "lft",                    limit: 4
    t.integer  "rgt",                    limit: 4
    t.boolean  "is_private",                           default: false, null: false
    t.datetime "closed_on"
    t.string   "mokuai_reason",          limit: 255
    t.string   "mokuai_name",            limit: 255
    t.string   "rom_version",            limit: 255
    t.boolean  "by_tester",                            default: true
    t.integer  "tfde_id",                limit: 4
    t.integer  "app_version_id",         limit: 4
    t.integer  "integration_version_id", limit: 4
    t.text     "umpirage_approver_id",   limit: 65535
    t.integer  "umpire_id",              limit: 4
  end

  add_index "issues", ["app_version_id"], name: "index_issues_on_app_version_id", using: :btree
  add_index "issues", ["assigned_to_id"], name: "index_issues_on_assigned_to_id", using: :btree
  add_index "issues", ["author_id"], name: "index_issues_on_author_id", using: :btree
  add_index "issues", ["by_tester"], name: "index_issues_on_by_tester", using: :btree
  add_index "issues", ["category_id"], name: "index_issues_on_category_id", using: :btree
  add_index "issues", ["created_on"], name: "index_issues_on_created_on", using: :btree
  add_index "issues", ["fixed_version_id"], name: "index_issues_on_fixed_version_id", using: :btree
  add_index "issues", ["integration_version_id"], name: "index_issues_on_integration_version_id", using: :btree
  add_index "issues", ["lock_version"], name: "index_issues_on_lock_version", using: :btree
  add_index "issues", ["mokuai_name"], name: "index_issues_on_mokuai_name", using: :btree
  add_index "issues", ["priority_id"], name: "index_issues_on_priority_id", using: :btree
  add_index "issues", ["project_id", "status_id"], name: "idx_on_project_id_and_status_id", using: :btree
  add_index "issues", ["project_id"], name: "issues_project_id", using: :btree
  add_index "issues", ["root_id", "lft", "rgt"], name: "index_issues_on_root_id_and_lft_and_rgt", using: :btree
  add_index "issues", ["status_id"], name: "index_issues_on_status_id", using: :btree
  add_index "issues", ["tfde_id"], name: "index_issues_on_tfde_id", using: :btree
  add_index "issues", ["tracker_id"], name: "index_issues_on_tracker_id", using: :btree
  add_index "issues", ["umpire_id"], name: "index_issues_on_umpire_id", using: :btree

  create_table "journal_details", force: :cascade do |t|
    t.integer "journal_id", limit: 4,     default: 0,  null: false
    t.string  "property",   limit: 30,    default: "", null: false
    t.string  "prop_key",   limit: 30,    default: "", null: false
    t.text    "old_value",  limit: 65535
    t.text    "value",      limit: 65535
  end

  add_index "journal_details", ["journal_id"], name: "journal_details_journal_id", using: :btree

  create_table "journals", force: :cascade do |t|
    t.integer  "journalized_id",   limit: 4,     default: 0,     null: false
    t.string   "journalized_type", limit: 30,    default: "",    null: false
    t.integer  "user_id",          limit: 4,     default: 0,     null: false
    t.text     "notes",            limit: 65535
    t.datetime "created_on",                                     null: false
    t.boolean  "private_notes",                  default: false, null: false
  end

  add_index "journals", ["created_on"], name: "index_journals_on_created_on", using: :btree
  add_index "journals", ["journalized_id", "journalized_type"], name: "journals_journalized_id", using: :btree
  add_index "journals", ["journalized_id"], name: "index_journals_on_journalized_id", using: :btree
  add_index "journals", ["user_id"], name: "index_journals_on_user_id", using: :btree

  create_table "libraries", force: :cascade do |t|
    t.integer  "container_id",   limit: 4
    t.string   "container_type", limit: 255
    t.string   "name",           limit: 255
    t.string   "path",           limit: 255
    t.string   "status",         limit: 255
    t.string   "change_type",    limit: 255
    t.integer  "user_id",        limit: 4
    t.text     "files",          limit: 65535
    t.integer  "uniq_key",       limit: 4
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  add_index "libraries", ["container_id", "container_type", "user_id"], name: "index_libraries_on_container_id_and_container_type_and_user_id", using: :btree

  create_table "library_files", force: :cascade do |t|
    t.integer  "library_id",    limit: 4
    t.text     "name",          limit: 65535
    t.string   "status",        limit: 255
    t.text     "conflict_type", limit: 65535
    t.string   "email",         limit: 255
    t.integer  "user_id",       limit: 4
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "library_files", ["library_id", "user_id"], name: "index_library_files_on_library_id_and_user_id", using: :btree

  create_table "member_roles", force: :cascade do |t|
    t.integer "member_id",      limit: 4, null: false
    t.integer "role_id",        limit: 4, null: false
    t.integer "inherited_from", limit: 4
  end

  add_index "member_roles", ["member_id"], name: "index_member_roles_on_member_id", using: :btree
  add_index "member_roles", ["role_id"], name: "index_member_roles_on_role_id", using: :btree

  create_table "members", force: :cascade do |t|
    t.integer  "user_id",           limit: 4, default: 0,     null: false
    t.integer  "project_id",        limit: 4, default: 0,     null: false
    t.datetime "created_on"
    t.boolean  "mail_notification",           default: false, null: false
  end

  add_index "members", ["project_id"], name: "index_members_on_project_id", using: :btree
  add_index "members", ["user_id", "project_id"], name: "index_members_on_user_id_and_project_id", unique: true, using: :btree
  add_index "members", ["user_id"], name: "index_members_on_user_id", using: :btree

  create_table "messages", force: :cascade do |t|
    t.integer  "board_id",      limit: 4,                     null: false
    t.integer  "parent_id",     limit: 4
    t.string   "subject",       limit: 255,   default: "",    null: false
    t.text     "content",       limit: 65535
    t.integer  "author_id",     limit: 4
    t.integer  "replies_count", limit: 4,     default: 0,     null: false
    t.integer  "last_reply_id", limit: 4
    t.datetime "created_on",                                  null: false
    t.datetime "updated_on",                                  null: false
    t.boolean  "locked",                      default: false
    t.integer  "sticky",        limit: 4,     default: 0
  end

  add_index "messages", ["author_id"], name: "index_messages_on_author_id", using: :btree
  add_index "messages", ["board_id"], name: "messages_board_id", using: :btree
  add_index "messages", ["created_on"], name: "index_messages_on_created_on", using: :btree
  add_index "messages", ["last_reply_id"], name: "index_messages_on_last_reply_id", using: :btree
  add_index "messages", ["parent_id"], name: "messages_parent_id", using: :btree

  create_table "mokuai_ownners", force: :cascade do |t|
    t.integer  "project_id", limit: 4
    t.integer  "mokuai_id",  limit: 4
    t.text     "ownner",     limit: 65535
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.integer  "tfde",       limit: 4
  end

  add_index "mokuai_ownners", ["mokuai_id"], name: "index_mokuai_ownners_on_mokuai_id", using: :btree
  add_index "mokuai_ownners", ["project_id"], name: "index_mokuai_ownners_on_project_id", using: :btree

  create_table "mokuais", force: :cascade do |t|
    t.integer  "category",     limit: 4
    t.string   "reason",       limit: 255
    t.string   "name",         limit: 255
    t.text     "description",  limit: 65535
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.integer  "default_tfde", limit: 4
    t.string   "package_name", limit: 255
  end

  create_table "native_applists", force: :cascade do |t|
    t.string   "name",         limit: 255
    t.string   "apk_name",     limit: 255
    t.string   "cn_name",      limit: 255
    t.string   "desktop_name", limit: 255
    t.text     "description",  limit: 65535
    t.string   "developer",    limit: 255
    t.text     "notes",        limit: 65535
    t.integer  "author_id",    limit: 4
    t.boolean  "deleted",                    default: false
    t.datetime "deleted_at"
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  create_table "new_features", force: :cascade do |t|
    t.integer  "category",    limit: 4
    t.string   "description", limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "news", force: :cascade do |t|
    t.integer  "project_id",     limit: 4
    t.string   "title",          limit: 60,    default: "", null: false
    t.string   "summary",        limit: 255,   default: ""
    t.text     "description",    limit: 65535
    t.integer  "author_id",      limit: 4,     default: 0,  null: false
    t.datetime "created_on"
    t.integer  "comments_count", limit: 4,     default: 0,  null: false
  end

  add_index "news", ["author_id"], name: "index_news_on_author_id", using: :btree
  add_index "news", ["created_on"], name: "index_news_on_created_on", using: :btree
  add_index "news", ["project_id"], name: "news_project_id", using: :btree

  create_table "notifications", force: :cascade do |t|
    t.string   "category",     limit: 255
    t.integer  "based_id",     limit: 4
    t.integer  "status",       limit: 4
    t.integer  "from_user_id", limit: 4
    t.integer  "to_user_id",   limit: 4
    t.string   "subject",      limit: 255
    t.text     "content",      limit: 65535
    t.boolean  "is_read",                    default: false
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  add_index "notifications", ["category", "to_user_id"], name: "idx_on_category", using: :btree

  create_table "okrs_key_results", force: :cascade do |t|
    t.text     "name",           limit: 65535
    t.integer  "container_id",   limit: 4
    t.string   "container_type", limit: 255
    t.float    "self_score",     limit: 24
    t.float    "other_score",    limit: 24
    t.text     "supported_by",   limit: 65535
    t.string   "uniq_key",       limit: 255
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "okrs_objects", force: :cascade do |t|
    t.text     "name",           limit: 65535
    t.integer  "container_id",   limit: 4
    t.string   "container_type", limit: 255
    t.string   "uniq_key",       limit: 255
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "okrs_records", force: :cascade do |t|
    t.text     "title",          limit: 65535
    t.string   "year_of_title",  limit: 255
    t.string   "month_of_title", limit: 255
    t.string   "dept_of_title",  limit: 255
    t.string   "status",         limit: 255
    t.text     "notes",          limit: 65535
    t.integer  "author_id",      limit: 4
    t.integer  "dept_id",        limit: 4
    t.integer  "approver_id",    limit: 4
    t.string   "record_type",    limit: 255
    t.integer  "parent_id",      limit: 4
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "okrs_settings", force: :cascade do |t|
    t.string   "cycle",           limit: 255
    t.string   "interval",        limit: 255
    t.string   "interval_type",   limit: 255
    t.string   "date",            limit: 255
    t.string   "time",            limit: 255
    t.datetime "last_running_at"
    t.integer  "author_id",       limit: 4
    t.integer  "closed_by_id",    limit: 4
    t.datetime "closed_at"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  create_table "okrs_supports", force: :cascade do |t|
    t.integer  "user_id",        limit: 4
    t.string   "user_name",      limit: 255
    t.integer  "okrs_record_id", limit: 4
    t.integer  "okrs_object_id", limit: 4
    t.integer  "container_id",   limit: 4
    t.string   "container_type", limit: 255
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  create_table "open_id_authentication_associations", force: :cascade do |t|
    t.integer "issued",     limit: 4
    t.integer "lifetime",   limit: 4
    t.string  "handle",     limit: 255
    t.string  "assoc_type", limit: 255
    t.binary  "server_url", limit: 65535
    t.binary  "secret",     limit: 65535
  end

  create_table "open_id_authentication_nonces", force: :cascade do |t|
    t.integer "timestamp",  limit: 4,   null: false
    t.string  "server_url", limit: 255
    t.string  "salt",       limit: 255, null: false
  end

  create_table "patch_versions", force: :cascade do |t|
    t.integer  "patch_id",            limit: 4
    t.string   "category",            limit: 255
    t.string   "name",                limit: 255
    t.integer  "object_id",           limit: 4
    t.string   "object_name",         limit: 255
    t.text     "version_url",         limit: 65535
    t.text     "version_log",         limit: 65535
    t.string   "status",              limit: 255
    t.string   "result",              limit: 255
    t.string   "operate_type",        limit: 255
    t.integer  "software_manager_id", limit: 4
    t.integer  "test_manager_id",     limit: 4
    t.integer  "user_id",             limit: 4
    t.string   "role_type",           limit: 255
    t.datetime "due_at"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
  end

  add_index "patch_versions", ["patch_id"], name: "index_patch_versions_on_patch_id", using: :btree

  create_table "patches", force: :cascade do |t|
    t.string   "patch_no",        limit: 255
    t.integer  "patch_type",      limit: 4
    t.string   "status",          limit: 255
    t.text     "init_command",    limit: 65535
    t.text     "notes",           limit: 65535
    t.integer  "author_id",       limit: 4
    t.string   "proprietary_tag", limit: 255
    t.text     "object_ids",      limit: 65535
    t.text     "object_names",    limit: 65535
    t.text     "reason",          limit: 65535
    t.date     "due_at"
    t.date     "actual_due_at"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.text     "jenkins_url",     limit: 65535
  end

  add_index "patches", ["author_id"], name: "index_patches_on_author_id", using: :btree

  create_table "periodic_tasks", force: :cascade do |t|
    t.string   "type",            limit: 255
    t.string   "name",            limit: 255
    t.text     "description",     limit: 65535
    t.string   "weekday",         limit: 255
    t.time     "time"
    t.text     "form_data",       limit: 65535
    t.integer  "status",          limit: 4
    t.text     "warning",         limit: 65535
    t.integer  "running_count",   limit: 4
    t.integer  "author_id",       limit: 4
    t.integer  "closed_by_id",    limit: 4
    t.datetime "last_running_on"
    t.datetime "closed_on"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  create_table "plans", force: :cascade do |t|
    t.integer  "project_id",       limit: 4
    t.integer  "parent_id",        limit: 4
    t.integer  "lft",              limit: 4
    t.integer  "rgt",              limit: 4
    t.string   "name",             limit: 255
    t.date     "plan_start_date"
    t.date     "plan_due_date"
    t.integer  "assigned_to_id",   limit: 4
    t.integer  "check_user_id",    limit: 4
    t.text     "description",      limit: 65535
    t.integer  "priority",         limit: 4
    t.integer  "author_id",        limit: 4
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.text     "assigned_to_note", limit: 65535
    t.text     "checker_note",     limit: 65535
    t.text     "author_note",      limit: 65535
    t.integer  "position",         limit: 4
  end

  add_index "plans", ["project_id", "name"], name: "index_plans_on_project_id_and_name", using: :btree

  create_table "project", id: false, force: :cascade do |t|
    t.string "project_name",      limit: 1536
    t.string "project_identify",  limit: 1536
    t.string "project_spec",      limit: 1536
    t.string "project_spec_desc", limit: 6144
    t.string "project_spm",       limit: 1536
    t.string "project_sqa",       limit: 1536
    t.string "project_sw",        limit: 1536
    t.string "project_dl",        limit: 1536
    t.string "project_test",      limit: 1536
    t.text   "package_repo",      limit: 65535
    t.text   "release_cc",        limit: 65535
    t.string "app_name",          limit: 1536
    t.string "app_spec_version",  limit: 1536
    t.text   "apk_repo",          limit: 65535
    t.text   "version_cc",        limit: 65535
  end

  create_table "project_apks", force: :cascade do |t|
    t.integer  "project_id",    limit: 4
    t.integer  "apk_base_id",   limit: 4
    t.integer  "author_id",     limit: 4
    t.boolean  "deleted",                 default: false
    t.integer  "deleted_by_id", limit: 4
    t.datetime "deleted_at"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
  end

  add_index "project_apks", ["project_id", "apk_base_id"], name: "project_apks_ids", unique: true, using: :btree

  create_table "projects", force: :cascade do |t|
    t.string   "name",                         limit: 255,   default: "",    null: false
    t.text     "description",                  limit: 65535
    t.string   "homepage",                     limit: 255,   default: ""
    t.boolean  "is_public",                                  default: true,  null: false
    t.integer  "parent_id",                    limit: 4
    t.datetime "created_on"
    t.datetime "updated_on"
    t.string   "identifier",                   limit: 255
    t.integer  "status",                       limit: 4,     default: 1,     null: false
    t.integer  "lft",                          limit: 4
    t.integer  "rgt",                          limit: 4
    t.boolean  "inherit_members",                            default: false, null: false
    t.integer  "default_version_id",           limit: 4
    t.string   "external_name",                limit: 255
    t.string   "cta_name",                     limit: 255
    t.string   "category",                     limit: 255
    t.string   "hardware_group",               limit: 255
    t.text     "approval_date",                limit: 65535
    t.text     "tone_date",                    limit: 65535
    t.text     "producing_date",               limit: 65535
    t.string   "rom_version",                  limit: 255
    t.integer  "mokuai_class",                 limit: 4
    t.string   "product_serie",                limit: 255
    t.text     "adaptive_date",                limit: 65535
    t.text     "full_featured_date",           limit: 65535
    t.text     "version_complete_date",        limit: 65535
    t.string   "ota_month",                    limit: 255
    t.text     "platform_version_export_date", limit: 65535
    t.text     "storage_version_export_date",  limit: 65535
    t.text     "storage_test_complete_date",   limit: 65535
    t.text     "storage_complete_date",        limit: 65535
    t.text     "initiate_date",                limit: 65535
    t.text     "release_date",                 limit: 65535
    t.integer  "ownership",                    limit: 4,     default: 1
    t.string   "package_name",                 limit: 255
    t.string   "dev_department",               limit: 255
    t.integer  "production_type",              limit: 4
    t.boolean  "plan_locked",                                default: false
    t.string   "cn_name",                      limit: 255
    t.string   "config_info",                  limit: 255
    t.text     "app_version_type",             limit: 65535
    t.string   "plan_status",                  limit: 255
    t.string   "next_step",                    limit: 255
    t.boolean  "has_adapter_report"
    t.text     "notes",                        limit: 65535
    t.integer  "android_platform",             limit: 4
    t.integer  "sub_production_type",          limit: 4
    t.text     "developer",                    limit: 65535
    t.text     "note",                         limit: 65535
  end

  add_index "projects", ["lft"], name: "index_projects_on_lft", using: :btree
  add_index "projects", ["rgt"], name: "index_projects_on_rgt", using: :btree
  add_index "projects", ["status"], name: "idx_on_status", using: :btree

  create_table "projects_repos", id: false, force: :cascade do |t|
    t.integer  "project_id", limit: 4,                null: false
    t.integer  "repo_id",    limit: 4,                null: false
    t.integer  "author_id",  limit: 4,                null: false
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.boolean  "freezed",              default: true
  end

  add_index "projects_repos", ["project_id", "freezed"], name: "idx_on_project_id_and_freezed", using: :btree
  add_index "projects_repos", ["project_id", "repo_id"], name: "projects_repos_unique", unique: true, using: :btree

  create_table "projects_trackers", id: false, force: :cascade do |t|
    t.integer "project_id", limit: 4, default: 0, null: false
    t.integer "tracker_id", limit: 4, default: 0, null: false
  end

  add_index "projects_trackers", ["project_id", "tracker_id"], name: "projects_trackers_unique", unique: true, using: :btree
  add_index "projects_trackers", ["project_id"], name: "projects_trackers_project_id", using: :btree

  create_table "qandas", force: :cascade do |t|
    t.string   "subject",    limit: 255
    t.text     "content",    limit: 65535
    t.string   "tag",        limit: 255
    t.integer  "total_read", limit: 4,     default: 0
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
  end

  create_table "queries", force: :cascade do |t|
    t.integer "project_id",    limit: 4
    t.string  "name",          limit: 255,   default: "", null: false
    t.text    "filters",       limit: 65535
    t.integer "user_id",       limit: 4,     default: 0,  null: false
    t.text    "column_names",  limit: 65535
    t.text    "sort_criteria", limit: 65535
    t.string  "group_by",      limit: 255
    t.string  "type",          limit: 255
    t.integer "visibility",    limit: 4,     default: 0
    t.text    "options",       limit: 65535
  end

  add_index "queries", ["project_id"], name: "index_queries_on_project_id", using: :btree
  add_index "queries", ["user_id"], name: "index_queries_on_user_id", using: :btree

  create_table "queries_roles", id: false, force: :cascade do |t|
    t.integer "query_id", limit: 4, null: false
    t.integer "role_id",  limit: 4, null: false
  end

  add_index "queries_roles", ["query_id", "role_id"], name: "queries_roles_ids", unique: true, using: :btree

  create_table "repo_requests", force: :cascade do |t|
    t.integer  "category",        limit: 4
    t.integer  "status",          limit: 4
    t.string   "server_ip",       limit: 255
    t.string   "android_repo",    limit: 255
    t.string   "package_repo",    limit: 255
    t.integer  "project_id",      limit: 4
    t.integer  "version_id",      limit: 4
    t.string   "tag_number",      limit: 255
    t.string   "branch",          limit: 255
    t.integer  "use",             limit: 4
    t.string   "production_type", limit: 255
    t.string   "repo_name",       limit: 255
    t.text     "write_users",     limit: 65535
    t.text     "read_users",      limit: 65535
    t.text     "submit_users",    limit: 65535
    t.text     "notes",           limit: 65535
    t.integer  "author_id",       limit: 4
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  create_table "report_condition_histories", force: :cascade do |t|
    t.integer  "from_id",    limit: 4
    t.integer  "user_id",    limit: 4
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "report_condition_histories", ["user_id"], name: "index_report_condition_histories_on_user_id", using: :btree

  create_table "report_conditions", force: :cascade do |t|
    t.integer  "condition_id", limit: 4
    t.text     "json",         limit: 65535
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  add_index "report_conditions", ["condition_id"], name: "index_report_conditions_on_condition_id", using: :btree

  create_table "repos", force: :cascade do |t|
    t.text     "description", limit: 65535
    t.integer  "category",    limit: 1,                     null: false
    t.string   "url",         limit: 255,                   null: false
    t.integer  "url_type",    limit: 1,                     null: false
    t.string   "name",        limit: 255
    t.string   "branch",      limit: 255
    t.boolean  "abandoned",                 default: false, null: false
    t.integer  "author_id",   limit: 4,                     null: false
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
  end

  create_table "repositories", force: :cascade do |t|
    t.integer  "project_id",    limit: 4,     default: 0,     null: false
    t.string   "url",           limit: 255,   default: "",    null: false
    t.string   "login",         limit: 60,    default: ""
    t.string   "password",      limit: 255,   default: ""
    t.string   "root_url",      limit: 255,   default: ""
    t.string   "type",          limit: 255
    t.string   "path_encoding", limit: 64
    t.string   "log_encoding",  limit: 64
    t.text     "extra_info",    limit: 65535
    t.string   "identifier",    limit: 255
    t.boolean  "is_default",                  default: false
    t.datetime "created_on"
  end

  add_index "repositories", ["project_id"], name: "index_repositories_on_project_id", using: :btree

  create_table "resourcings", force: :cascade do |t|
    t.integer "user_id",     limit: 4
    t.text    "permissions", limit: 65535
  end

  add_index "resourcings", ["user_id"], name: "index_resourcings_on_user_id", using: :btree

  create_table "risk_measures", force: :cascade do |t|
    t.integer  "risk_id",    limit: 4
    t.text     "content",    limit: 65535
    t.datetime "finish_at"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "risk_measures", ["risk_id"], name: "index_risk_measures_on_risk_id", using: :btree

  create_table "risks", force: :cascade do |t|
    t.integer  "project_id",  limit: 4
    t.string   "department",  limit: 255
    t.string   "category",    limit: 255
    t.text     "description", limit: 65535
    t.integer  "user_id",     limit: 4
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "risks", ["project_id"], name: "index_risks_on_project_id", using: :btree
  add_index "risks", ["user_id"], name: "index_risks_on_user_id", using: :btree

  create_table "roles", force: :cascade do |t|
    t.string  "name",                    limit: 30,    default: "",        null: false
    t.integer "position",                limit: 4
    t.boolean "assignable",                            default: true
    t.integer "builtin",                 limit: 4,     default: 0,         null: false
    t.text    "permissions",             limit: 65535
    t.string  "issues_visibility",       limit: 30,    default: "default", null: false
    t.string  "users_visibility",        limit: 30,    default: "all",     null: false
    t.string  "time_entries_visibility", limit: 30,    default: "all",     null: false
    t.boolean "all_roles_managed",                     default: true,      null: false
    t.text    "settings",                limit: 65535
  end

  create_table "roles_managed_roles", id: false, force: :cascade do |t|
    t.integer "role_id",         limit: 4, null: false
    t.integer "managed_role_id", limit: 4, null: false
  end

  add_index "roles_managed_roles", ["role_id", "managed_role_id"], name: "index_roles_managed_roles_on_role_id_and_managed_role_id", unique: true, using: :btree

  create_table "sessions", force: :cascade do |t|
    t.string   "session_id", limit: 255,   null: false
    t.string   "cas_ticket", limit: 255
    t.text     "data",       limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["cas_ticket"], name: "index_sessions_on_cas_ticket", using: :btree
  add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", using: :btree
  add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at", using: :btree

  create_table "settings", force: :cascade do |t|
    t.string   "name",       limit: 255,   default: "", null: false
    t.text     "value",      limit: 65535
    t.datetime "updated_on"
  end

  add_index "settings", ["name"], name: "index_settings_on_name", using: :btree

  create_table "signatures", force: :cascade do |t|
    t.string   "name",         limit: 255
    t.integer  "category",     limit: 4
    t.string   "key_name",     limit: 255
    t.string   "status",       limit: 255
    t.text     "upload_url",   limit: 65535
    t.text     "download_url", limit: 65535
    t.text     "infos",        limit: 65535
    t.text     "notes",        limit: 65535
    t.integer  "author_id",    limit: 4
    t.datetime "due_at"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  add_index "signatures", ["author_id"], name: "index_signatures_on_author_id", using: :btree

  create_table "spec_alter_records", force: :cascade do |t|
    t.integer  "spec_id",     limit: 4
    t.integer  "user_id",     limit: 4
    t.integer  "record_type", limit: 4,     default: 0
    t.string   "prop_key",    limit: 255
    t.string   "old_value",   limit: 255
    t.string   "value",       limit: 255
    t.text     "note",        limit: 65535
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
    t.integer  "app_id",      limit: 4
  end

  add_index "spec_alter_records", ["spec_id"], name: "index_spec_alter_records_on_spec_id", using: :btree
  add_index "spec_alter_records", ["user_id"], name: "index_spec_alter_records_on_user_id", using: :btree

  create_table "spec_versions", force: :cascade do |t|
    t.integer  "spec_id",       limit: 4
    t.integer  "production_id", limit: 4
    t.integer  "version_id",    limit: 4
    t.boolean  "deleted",                     default: false
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "mark",          limit: 65535
    t.text     "release_path",  limit: 65535
    t.boolean  "freezed",                     default: false
    t.string   "cn_name",       limit: 255
    t.string   "desktop_name",  limit: 255
    t.text     "description",   limit: 65535
    t.string   "developer",     limit: 255
    t.text     "notes",         limit: 65535
  end

  add_index "spec_versions", ["spec_id"], name: "index_spec_versions_on_spec_id", using: :btree
  add_index "spec_versions", ["version_id"], name: "index_spec_versions_on_version_id", using: :btree

  create_table "specs", force: :cascade do |t|
    t.integer  "project_id",           limit: 4
    t.string   "name",                 limit: 255
    t.datetime "jh_collect_finish_dt"
    t.datetime "sj_collect_finish_dt"
    t.boolean  "deleted",                            default: false
    t.boolean  "locked",                             default: false
    t.boolean  "is_default",                         default: false
    t.text     "note",                 limit: 65535
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
    t.boolean  "is_colleted",                        default: false
    t.boolean  "freezed",                            default: false
    t.integer  "for_new",              limit: 4
  end

  add_index "specs", ["deleted"], name: "index_specs_on_deleted", using: :btree
  add_index "specs", ["for_new"], name: "index_specs_on_for_new", using: :btree
  add_index "specs", ["project_id"], name: "index_specs_on_project_id", using: :btree

  create_table "tasks", force: :cascade do |t|
    t.integer  "container_id",      limit: 4
    t.string   "container_type",    limit: 255
    t.string   "name",              limit: 255
    t.integer  "assigned_to_id",    limit: 4
    t.integer  "author_id",         limit: 4
    t.integer  "status",            limit: 4,     default: 1
    t.text     "description",       limit: 65535
    t.text     "notes",             limit: 65535
    t.datetime "start_date"
    t.datetime "due_date"
    t.datetime "actual_start_date"
    t.datetime "actual_due_date"
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.boolean  "is_read",                         default: false
  end

  add_index "tasks", ["assigned_to_id"], name: "index_on_assigned_to_id", using: :btree
  add_index "tasks", ["container_id", "container_type"], name: "index_attachments_on_container_id_and_container_type", using: :btree

  create_table "templates", force: :cascade do |t|
    t.integer  "role_id",     limit: 4
    t.integer  "object_id",   limit: 4
    t.integer  "object_type", limit: 4
    t.integer  "role_type",   limit: 4
    t.integer  "author_id",   limit: 4
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  add_index "templates", ["object_id"], name: "templates_object_id", using: :btree
  add_index "templates", ["role_id"], name: "templates_role_id", using: :btree

  create_table "thirdparties", force: :cascade do |t|
    t.integer  "spec_id",      limit: 4
    t.integer  "author_id",    limit: 4
    t.integer  "status",       limit: 4,     default: 1
    t.text     "version_ids",  limit: 65535
    t.text     "note",         limit: 65535
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.text     "result",       limit: 65535
    t.integer  "category",     limit: 4
    t.text     "release_ids",  limit: 65535
    t.integer  "release_type", limit: 4
  end

  create_table "time_entries", force: :cascade do |t|
    t.integer  "project_id",  limit: 4,    null: false
    t.integer  "user_id",     limit: 4,    null: false
    t.integer  "issue_id",    limit: 4
    t.float    "hours",       limit: 24,   null: false
    t.string   "comments",    limit: 1024
    t.integer  "activity_id", limit: 4,    null: false
    t.date     "spent_on",                 null: false
    t.integer  "tyear",       limit: 4,    null: false
    t.integer  "tmonth",      limit: 4,    null: false
    t.integer  "tweek",       limit: 4,    null: false
    t.datetime "created_on",               null: false
    t.datetime "updated_on",               null: false
  end

  add_index "time_entries", ["activity_id"], name: "index_time_entries_on_activity_id", using: :btree
  add_index "time_entries", ["created_on"], name: "index_time_entries_on_created_on", using: :btree
  add_index "time_entries", ["issue_id"], name: "time_entries_issue_id", using: :btree
  add_index "time_entries", ["project_id"], name: "time_entries_project_id", using: :btree
  add_index "time_entries", ["user_id"], name: "index_time_entries_on_user_id", using: :btree

  create_table "timelines", force: :cascade do |t|
    t.integer  "container_id",   limit: 4
    t.string   "container_type", limit: 255
    t.string   "name",           limit: 255
    t.string   "group_key",      limit: 255
    t.integer  "related_id",     limit: 4
    t.integer  "parent_id",      limit: 4
    t.boolean  "enable",                     default: true
    t.integer  "author_id",      limit: 4
    t.integer  "time_display",   limit: 4,   default: 1
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
  end

  create_table "tokens", force: :cascade do |t|
    t.integer  "user_id",    limit: 4,  default: 0,  null: false
    t.string   "action",     limit: 30, default: "", null: false
    t.string   "value",      limit: 40, default: "", null: false
    t.datetime "created_on",                         null: false
    t.datetime "updated_on"
  end

  add_index "tokens", ["user_id"], name: "index_tokens_on_user_id", using: :btree
  add_index "tokens", ["value"], name: "tokens_value", unique: true, using: :btree

  create_table "tools", force: :cascade do |t|
    t.integer  "category",    limit: 4
    t.string   "name",        limit: 255
    t.text     "description", limit: 65535
    t.text     "notes",       limit: 65535
    t.integer  "provider_id", limit: 4
    t.integer  "author_id",   limit: 4
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "tools", ["provider_id", "author_id"], name: "index_tools_on_provider_id_and_author_id", using: :btree

  create_table "top_notices", force: :cascade do |t|
    t.integer  "receiver_type", limit: 4
    t.string   "receivers",     limit: 255
    t.string   "message",       limit: 255
    t.date     "expired"
    t.string   "uniq_key",      limit: 255
    t.integer  "user_id",       limit: 4
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "top_notices", ["user_id"], name: "index_top_notices_on_user_id", using: :btree

  create_table "trackers", force: :cascade do |t|
    t.string  "name",              limit: 30, default: "",    null: false
    t.boolean "is_in_chlog",                  default: false, null: false
    t.integer "position",          limit: 4
    t.boolean "is_in_roadmap",                default: true,  null: false
    t.integer "fields_bits",       limit: 4,  default: 0
    t.integer "default_status_id", limit: 4
  end

  create_table "user_favors", force: :cascade do |t|
    t.integer  "user_id",    limit: 4
    t.string   "title",      limit: 255
    t.string   "url",        limit: 255
    t.integer  "sort",       limit: 4
    t.integer  "status",     limit: 4,   default: 1
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  add_index "user_favors", ["user_id"], name: "index_user_favors_on_user_id", using: :btree

  create_table "user_preferences", force: :cascade do |t|
    t.integer "user_id",   limit: 4,     default: 0,    null: false
    t.text    "others",    limit: 65535
    t.boolean "hide_mail",               default: true
    t.string  "time_zone", limit: 255
  end

  add_index "user_preferences", ["user_id"], name: "index_user_preferences_on_user_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "login",                limit: 255, default: "",    null: false
    t.string   "hashed_password",      limit: 40,  default: "",    null: false
    t.string   "firstname",            limit: 30,  default: "",    null: false
    t.string   "lastname",             limit: 255, default: "",    null: false
    t.boolean  "admin",                            default: false, null: false
    t.integer  "status",               limit: 4,   default: 1,     null: false
    t.datetime "last_login_on"
    t.string   "language",             limit: 5,   default: ""
    t.integer  "auth_source_id",       limit: 4
    t.datetime "created_on"
    t.datetime "updated_on"
    t.string   "type",                 limit: 255
    t.string   "identity_url",         limit: 255
    t.string   "mail_notification",    limit: 255, default: "",    null: false
    t.string   "salt",                 limit: 64
    t.boolean  "must_change_passwd",               default: false, null: false
    t.datetime "passwd_changed_on"
    t.datetime "birthday"
    t.string   "deptSysNm",            limit: 50
    t.string   "sub_system",           limit: 50
    t.string   "empId",                limit: 20
    t.string   "group_bmjl_empId",     limit: 20
    t.string   "group_bmjl_id",        limit: 20
    t.string   "group_bmjl_name",      limit: 15
    t.string   "group_fujingli_empId", limit: 20
    t.string   "group_fujingli_name",  limit: 15
    t.string   "group_zgfz_empId",     limit: 20
    t.string   "group_zgfz_id",        limit: 20
    t.string   "group_zgfz_name",      limit: 15
    t.string   "group_zhuguan_empId",  limit: 20
    t.string   "group_zhuguan_id",     limit: 20
    t.string   "group_zhuguan_name",   limit: 15
    t.string   "group_zongjian_empId", limit: 20
    t.string   "group_zongjian_id",    limit: 20
    t.string   "group_zongjian_name",  limit: 15
    t.string   "jobNm",                limit: 30
    t.string   "mobile",               limit: 30
    t.string   "phone",                limit: 30
    t.string   "orgNm",                limit: 50
    t.string   "orgNo",                limit: 20
    t.string   "parentNo",             limit: 20
    t.string   "parentOrgNm",          limit: 50
    t.string   "scoChrNm",             limit: 50
    t.string   "scoChrNo",             limit: 20
    t.string   "scoNm",                limit: 50
    t.string   "scoNo",                limit: 20
    t.string   "spm",                  limit: 50
    t.string   "product",              limit: 50
    t.string   "qq",                   limit: 15
    t.string   "picture",              limit: 255
    t.boolean  "gender"
    t.string   "native_place",         limit: 255
    t.string   "married",              limit: 255
    t.date     "entry_date"
    t.string   "pinyin",               limit: 255
  end

  add_index "users", ["auth_source_id"], name: "index_users_on_auth_source_id", using: :btree
  add_index "users", ["id", "type"], name: "index_users_on_id_and_type", using: :btree
  add_index "users", ["orgNo"], name: "index_users_on_orgNo", using: :btree
  add_index "users", ["type"], name: "index_users_on_type", using: :btree

  create_table "v_approve_merge_tasks", id: false, force: :cascade do |t|
    t.integer  "project_id",          limit: 4,                  null: false
    t.string   "project_name",        limit: 255,   default: "", null: false
    t.integer  "task_id",             limit: 4,     default: 0,  null: false
    t.string   "task_name",           limit: 255
    t.integer  "task_assigned_to_id", limit: 4
    t.string   "container_type",      limit: 255
    t.integer  "status_id",           limit: 4,     default: 1
    t.string   "status_name",         limit: 4
    t.string   "signed_to",           limit: 30,    default: ""
    t.integer  "issue_id",            limit: 4
    t.text     "reason",              limit: 65535
    t.text     "requirement",         limit: 65535
    t.datetime "created_at",                                     null: false
  end

  create_table "version_applists", force: :cascade do |t|
    t.integer  "version_id",           limit: 4
    t.integer  "app_version_id",       limit: 4
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.string   "apk_name",             limit: 255
    t.string   "apk_size",             limit: 255
    t.string   "apk_interior_version", limit: 255
    t.text     "apk_permission",       limit: 65535
    t.boolean  "apk_removable"
    t.boolean  "apk_uploaded"
    t.string   "apk_cn_name",          limit: 255
    t.boolean  "apk_desktop"
    t.boolean  "apk_size_comparable"
  end

  add_index "version_applists", ["version_id"], name: "index_version_applists_on_version_id", using: :btree

  create_table "version_issues", force: :cascade do |t|
    t.integer  "version_id",  limit: 4
    t.integer  "issue_type",  limit: 4
    t.integer  "issue_id",    limit: 4
    t.string   "status",      limit: 255
    t.string   "subject",     limit: 255
    t.string   "assigned_to", limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_index "version_issues", ["version_id"], name: "index_version_issues_on_version_id", using: :btree

  create_table "version_name_rules", force: :cascade do |t|
    t.string   "name",             limit: 255
    t.text     "description",      limit: 65535
    t.string   "range",            limit: 255
    t.integer  "author_id",        limit: 4
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.integer  "android_platform", limit: 4
  end

  create_table "version_permissions", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.text     "meaning",       limit: 65535
    t.integer  "author_id",     limit: 4
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.boolean  "deleted",                     default: false
    t.integer  "deleted_by_id", limit: 4
  end

  create_table "version_publishes", force: :cascade do |t|
    t.integer  "version_id",   limit: 4
    t.text     "content",      limit: 65535
    t.string   "content_md5",  limit: 255
    t.boolean  "published",                  default: false
    t.integer  "author_id",    limit: 4
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
    t.text     "notes",        limit: 65535
    t.integer  "spec_id",      limit: 4
    t.datetime "published_on"
    t.integer  "publisher_id", limit: 4
  end

  create_table "version_release_sdks", force: :cascade do |t|
    t.integer  "version_id",          limit: 4
    t.integer  "status",              limit: 4
    t.text     "result",              limit: 16777215
    t.text     "maven_result",        limit: 16777215
    t.text     "release_project_ids", limit: 16777215
    t.integer  "author_id",           limit: 4
    t.text     "note",                limit: 16777215
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
  end

  create_table "version_releases", force: :cascade do |t|
    t.integer  "project_id",                 limit: 4,                     null: false
    t.integer  "category",                   limit: 4,                     null: false
    t.integer  "version_id",                 limit: 4
    t.string   "version_applicable_to",      limit: 255
    t.string   "tested_mobile",              limit: 255
    t.datetime "test_finished_on"
    t.integer  "author_id",                  limit: 4
    t.integer  "test_type",                  limit: 4
    t.integer  "bvt_test",                   limit: 4
    t.integer  "fluency_test",               limit: 4
    t.integer  "response_time_test",         limit: 4
    t.integer  "sonar_codes_check",          limit: 4
    t.integer  "app_standby_test",           limit: 4
    t.integer  "monkey_72_test",             limit: 4
    t.integer  "memory_leak_test",           limit: 4
    t.integer  "cts_test",                   limit: 4
    t.integer  "cts_verifier_test",          limit: 4
    t.integer  "interior_invoke_warning",    limit: 4
    t.integer  "related_invoke_warning",     limit: 4
    t.string   "relative_objects",           limit: 255
    t.boolean  "codes_reviewed"
    t.boolean  "cases_sync_updated"
    t.string   "issues_for_platform",        limit: 255
    t.boolean  "code_walkthrough_well"
    t.text     "failed_info",                limit: 65535
    t.string   "path",                       limit: 255
    t.integer  "mode",                       limit: 4
    t.integer  "sdk_review",                 limit: 4
    t.text     "description",                limit: 65535
    t.text     "remaining_issues",           limit: 65535
    t.text     "new_issues",                 limit: 65535
    t.integer  "ued_confirm",                limit: 4
    t.text     "note",                       limit: 65535
    t.boolean  "uir_upload_to_svn"
    t.text     "result",                     limit: 65535
    t.datetime "created_at",                                               null: false
    t.datetime "updated_at",                                               null: false
    t.string   "mail_receivers",             limit: 255
    t.string   "server_version",             limit: 255
    t.string   "validation_results",         limit: 255
    t.string   "other_app",                  limit: 255
    t.text     "note_one",                   limit: 65535
    t.text     "note_two",                   limit: 65535
    t.integer  "status",                     limit: 4,     default: 0
    t.integer  "failed_count",               limit: 4
    t.integer  "parent_id",                  limit: 4
    t.text     "ued_check_result",           limit: 65535
    t.text     "sqa_check_result",           limit: 65535
    t.text     "additional_note",            limit: 65535
    t.boolean  "has_problem",                              default: false
    t.integer  "translate_sync",             limit: 4
    t.integer  "output_record_sync",         limit: 4
    t.integer  "app_data_test",              limit: 4
    t.integer  "app_launch_test",            limit: 4
    t.integer  "translate_autocheck_result", limit: 4
  end

  add_index "version_releases", ["version_id"], name: "index_version_releases_on_version_id", using: :btree

  create_table "versions", force: :cascade do |t|
    t.integer  "project_id",            limit: 4,     default: 0,      null: false
    t.string   "name",                  limit: 255,   default: "",     null: false
    t.text     "description",           limit: 65535
    t.date     "effective_date"
    t.datetime "created_on"
    t.datetime "updated_on"
    t.string   "wiki_page_title",       limit: 255
    t.integer  "status",                limit: 4,     default: 1
    t.string   "sharing",               limit: 255,   default: "none", null: false
    t.string   "production_name",       limit: 255
    t.text     "baseline",              limit: 65535
    t.text     "label",                 limit: 65535
    t.text     "path",                  limit: 65535
    t.integer  "repo_one_id",           limit: 4
    t.integer  "repo_two_id",           limit: 4
    t.integer  "repo_three_id",         limit: 4
    t.integer  "priority",              limit: 4
    t.integer  "compile_status",        limit: 4
    t.integer  "last_version_id",       limit: 4
    t.string   "log_url",               limit: 255
    t.integer  "compile_type",          limit: 4
    t.boolean  "ota_whole_compile"
    t.boolean  "ota_increase_compile"
    t.string   "ota_increase_versions", limit: 255
    t.boolean  "as_increase_version"
    t.boolean  "signature"
    t.integer  "spec_id",               limit: 4
    t.boolean  "continue_integration"
    t.integer  "arm",                   limit: 4
    t.boolean  "strengthen",                          default: false
    t.boolean  "auto_test",                           default: false
    t.boolean  "unit_test",                           default: false
    t.string   "auto_test_projects",    limit: 255
    t.boolean  "sonar_test",                          default: false
    t.integer  "parent_id",             limit: 4
    t.string   "compile_machine",       limit: 255
    t.integer  "author_id",             limit: 4
    t.integer  "rom_project_id",        limit: 4
    t.integer  "stopped_user_id",       limit: 4
    t.datetime "compile_stop_on"
    t.datetime "compile_start_on"
    t.datetime "compile_end_on"
    t.datetime "compile_due_on"
    t.boolean  "has_unit_test_report",                default: false
    t.string   "mail_receivers",        limit: 255
    t.string   "group_key",             limit: 255
    t.string   "warning",               limit: 255
    t.boolean  "coverity"
    t.string   "timezone",              limit: 255
    t.string   "finger_print",          limit: 255
    t.text     "system_space",          limit: 65535
    t.string   "gradle_version",        limit: 255
    t.text     "special_app_versions",  limit: 65535
    t.text     "version_yaml",          limit: 65535
    t.datetime "sendtest_at"
  end

  add_index "versions", ["project_id"], name: "versions_project_id", using: :btree
  add_index "versions", ["sharing"], name: "index_versions_on_sharing", using: :btree
  add_index "versions", ["spec_id"], name: "index_versions_on_spec_id", using: :btree

  create_table "view_records", force: :cascade do |t|
    t.integer  "container_id",   limit: 4
    t.string   "container_type", limit: 255
    t.integer  "user_id",        limit: 4
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  add_index "view_records", ["container_id", "container_type"], name: "index_view_records_on_container_id_and_container_type", using: :btree
  add_index "view_records", ["user_id"], name: "index_view_records_on_user_id", using: :btree

  create_table "watchers", force: :cascade do |t|
    t.string  "watchable_type", limit: 255, default: "", null: false
    t.integer "watchable_id",   limit: 4,   default: 0,  null: false
    t.integer "user_id",        limit: 4
  end

  add_index "watchers", ["user_id", "watchable_type"], name: "watchers_user_id_type", using: :btree
  add_index "watchers", ["user_id"], name: "index_watchers_on_user_id", using: :btree
  add_index "watchers", ["watchable_id", "watchable_type"], name: "index_watchers_on_watchable_id_and_watchable_type", using: :btree

  create_table "wiki_content_versions", force: :cascade do |t|
    t.integer  "wiki_content_id", limit: 4,                       null: false
    t.integer  "page_id",         limit: 4,                       null: false
    t.integer  "author_id",       limit: 4
    t.binary   "data",            limit: 4294967295
    t.string   "compression",     limit: 6,          default: ""
    t.string   "comments",        limit: 1024,       default: ""
    t.datetime "updated_on",                                      null: false
    t.integer  "version",         limit: 4,                       null: false
  end

  add_index "wiki_content_versions", ["updated_on"], name: "index_wiki_content_versions_on_updated_on", using: :btree
  add_index "wiki_content_versions", ["wiki_content_id"], name: "wiki_content_versions_wcid", using: :btree

  create_table "wiki_contents", force: :cascade do |t|
    t.integer  "page_id",    limit: 4,                       null: false
    t.integer  "author_id",  limit: 4
    t.text     "text",       limit: 4294967295
    t.string   "comments",   limit: 1024,       default: ""
    t.datetime "updated_on",                                 null: false
    t.integer  "version",    limit: 4,                       null: false
  end

  add_index "wiki_contents", ["author_id"], name: "index_wiki_contents_on_author_id", using: :btree
  add_index "wiki_contents", ["page_id"], name: "wiki_contents_page_id", using: :btree

  create_table "wiki_pages", force: :cascade do |t|
    t.integer  "wiki_id",    limit: 4,                   null: false
    t.string   "title",      limit: 255,                 null: false
    t.datetime "created_on",                             null: false
    t.boolean  "protected",              default: false, null: false
    t.integer  "parent_id",  limit: 4
  end

  add_index "wiki_pages", ["parent_id"], name: "index_wiki_pages_on_parent_id", using: :btree
  add_index "wiki_pages", ["wiki_id", "title"], name: "wiki_pages_wiki_id_title", using: :btree
  add_index "wiki_pages", ["wiki_id"], name: "index_wiki_pages_on_wiki_id", using: :btree

  create_table "wiki_redirects", force: :cascade do |t|
    t.integer  "wiki_id",              limit: 4,   null: false
    t.string   "title",                limit: 255
    t.string   "redirects_to",         limit: 255
    t.datetime "created_on",                       null: false
    t.integer  "redirects_to_wiki_id", limit: 4,   null: false
  end

  add_index "wiki_redirects", ["wiki_id", "title"], name: "wiki_redirects_wiki_id_title", using: :btree
  add_index "wiki_redirects", ["wiki_id"], name: "index_wiki_redirects_on_wiki_id", using: :btree

  create_table "wikis", force: :cascade do |t|
    t.integer "project_id", limit: 4,               null: false
    t.string  "start_page", limit: 255,             null: false
    t.integer "status",     limit: 4,   default: 1, null: false
  end

  add_index "wikis", ["project_id"], name: "wikis_project_id", using: :btree

  create_table "workflows", force: :cascade do |t|
    t.integer "tracker_id",    limit: 4,  default: 0,     null: false
    t.integer "old_status_id", limit: 4,  default: 0,     null: false
    t.integer "new_status_id", limit: 4,  default: 0,     null: false
    t.integer "role_id",       limit: 4,  default: 0,     null: false
    t.boolean "assignee",                 default: false, null: false
    t.boolean "author",                   default: false, null: false
    t.string  "type",          limit: 30
    t.string  "field_name",    limit: 30
    t.string  "rule",          limit: 30
  end

  add_index "workflows", ["new_status_id"], name: "index_workflows_on_new_status_id", using: :btree
  add_index "workflows", ["old_status_id"], name: "index_workflows_on_old_status_id", using: :btree
  add_index "workflows", ["role_id", "tracker_id", "old_status_id"], name: "wkfs_role_tracker_old_status", using: :btree
  add_index "workflows", ["role_id"], name: "index_workflows_on_role_id", using: :btree

  add_foreign_key "approvals", "users"
  add_foreign_key "condition_histories", "users"
  add_foreign_key "default_values", "users"
  add_foreign_key "issue_gerrits", "issues"
  add_foreign_key "issue_gerrits", "users"
  add_foreign_key "mokuai_ownners", "mokuais"
  add_foreign_key "mokuai_ownners", "projects"
  add_foreign_key "report_condition_histories", "users"
  add_foreign_key "report_conditions", "conditions"
  add_foreign_key "resourcings", "users"
  add_foreign_key "risk_measures", "risks"
  add_foreign_key "risks", "projects"
  add_foreign_key "risks", "users"
  add_foreign_key "specs", "projects"
  add_foreign_key "user_favors", "users"
end
