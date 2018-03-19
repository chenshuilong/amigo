class CreateIssueHistories < ActiveRecord::Migration
  def change
    create_table :issue_histories do |t|
      t.datetime  :date
      t.integer   :issue_id
      t.integer   :status_id
      t.integer   :assigned_to_id
      t.integer   :project_id
      t.integer   :priority_id
      t.string    :probability_id
      t.integer   :mokuai_name
    end
  end
end
