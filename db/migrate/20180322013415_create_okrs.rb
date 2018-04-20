class CreateOkrs < ActiveRecord::Migration
  def change
    create_table :okrs_records do |t|
      t.text     :title
      t.string   :year_of_title
      t.string   :month_of_title
      t.string   :dept_of_title
      t.string   :status
      t.text     :notes
      t.integer  :author_id
      t.integer  :dept_id
      t.integer  :approver_id
      t.string   :record_type
      t.integer  :parent_id

      t.timestamps :null => false
    end

    create_table :okrs_objects do |t|
      t.text     :name
      t.integer  :container_id
      t.string   :container_type
      t.string   :uniq_key

      t.timestamps :null => false
    end

    create_table :okrs_key_results do |t|
      t.text     :name
      t.integer  :container_id
      t.string   :container_type
      t.float    :self_score
      t.float    :other_score
      t.text     :supported_by
      t.string   :uniq_key

      t.timestamps :null => false
    end

    create_table :okrs_settings do |t|
      t.string   :cycle
      t.string   :interval
      t.string   :interval_type
      t.string   :date
      t.string   :time
      t.datetime :last_running_at
      t.integer  :author_id
      t.integer  :closed_by_id
      t.datetime :closed_at

      t.timestamps :null => false
    end
  end
end
