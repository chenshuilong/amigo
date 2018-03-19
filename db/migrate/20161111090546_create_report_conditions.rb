class CreateReportConditions < ActiveRecord::Migration
  def change
    create_table :report_conditions do |t|
      t.references :condition, index: true, foreign_key: true
      t.text :json

      t.timestamps null: false
    end

    Condition.where("category in (3,4)").each do |con|
      ReportCondition
          .create({
                      :condition_id => con.id,
                      :json => "{\"auto\":0,\"groupby\":\"issues.assigned_to_id\",\"charttype\":\"bar\",
                                  \"dwm_yn\":0,\"dwm\":\"day\",\"start_dt\":\"2016-09-01\",
                                  \"end_dt\":\"#{Time.now.strftime('%Y-%m-%d')}\"}"
                  })
    end
  end
end
