class CreateIssueToSpecialTest < ActiveRecord::Migration
  def change
    create_table :issue_to_special_tests do |t|
    	t.integer :project_id
      t.integer :category
      t.string  :subject
      t.integer :status
      t.string  :related_issues
      t.string  :test_times
      t.boolean :log_from_com
      t.string  :machine_num
      t.text    :test_method
      t.text    :attentions
      t.string  :test_version
      t.integer :priority
      t.text    :approval_result
      t.integer :author_id

      t.timestamps null: false
    end

    create_table :issue_to_special_test_results do |t|
      t.integer :special_test_id
      t.integer :designer_id
      t.integer :assigned_to_id
      t.text    :steps
      t.string  :sample_num
      t.string  :catch_log_way
      t.integer :result
      t.text    :notes
      t.datetime :start_date
      t.datetime :due_date

      t.timestamps null: false
    end
  end
end
