class ChangeForNewForSpec < ActiveRecord::Migration
  def up
    say_with_time "Changing column on specs, this may take some time..." do
      change_column :specs, :for_new, :integer
      add_index :specs, :for_new
      add_column :spec_versions, :freezed, :boolean, default: false

      Spec.where(:for_new => 0).update_all(:for_new => 2)
      Spec.where(:for_new => 1).update_all(:for_new => 3)

      SpecAlterRecord.where(:prop_key => "spec_for_new", :old_value => 0).update_all(:old_value => 2)
      SpecAlterRecord.where(:prop_key => "spec_for_new", :old_value => 1).update_all(:old_value => 3)

      SpecAlterRecord.where(:prop_key => "spec_for_new", :value => 0).update_all(:value => 2)
      SpecAlterRecord.where(:prop_key => "spec_for_new", :value => 1).update_all(:value => 3)
    end
  end

  def down
    change_column :specs, :for_new, :boolean
    remove_column :spec_versions, :freezed

    Spec.where(:for_new => 3).update_all(:for_new => 1)
    Spec.where(:for_new => 2).update_all(:for_new => 0)

    SpecAlterRecord.where(:prop_key => "spec_for_new", :old_value => 3).update_all(:old_value => 1)
    SpecAlterRecord.where(:prop_key => "spec_for_new", :old_value => 2).update_all(:old_value => 0)

    SpecAlterRecord.where(:prop_key => "spec_for_new", :value => 3).update_all(:value => 1)
    SpecAlterRecord.where(:prop_key => "spec_for_new", :value => 2).update_all(:value => 0)
  end
end
