class CreatePeriodicTasks < ActiveRecord::Migration
  def change
    create_table :periodic_tasks do |t|
      t.string          :type
      t.string          :name
      t.text            :description
      t.string          :weekday
      t.time            :time
      t.text            :form_data
      t.integer         :status
      t.text            :warning
      t.integer         :running_count
      t.integer         :author_id
      t.integer         :closed_by_id
      t.datetime        :last_running_on
      t.datetime        :closed_on
      t.timestamps null: false
    end
  end
end
