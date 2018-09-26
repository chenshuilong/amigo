class AddMktypeToThirdparty < ActiveRecord::Migration
  def change
    add_column :thirdparties, :mk_type, :integer, default: 1
  end
end
