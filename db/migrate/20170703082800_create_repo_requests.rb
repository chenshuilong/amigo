class CreateRepoRequests < ActiveRecord::Migration
  def change
    create_table :repo_requests do |t|
      t.integer :category
      t.integer :status
      t.string :server_ip
      t.string :android_repo
      t.string :package_repo
      t.integer :project_id
      t.integer :version_id
      t.string :branch
      t.integer :use
      t.text :write_users
      t.text :read_users
      t.text :submit_users
      t.text :notes
      t.integer :author_id

      t.timestamps null: false
    end

    create_table :custom_permissions do |t|
      t.integer :user_id
      t.string  :permission_type
      t.integer :author_id
      t.text    :notes
      t.boolean :locked, default: false
      t.references :user, index: true

      t.timestamps null: false
    end

    add_column :repos, :branch, :string, :after => :url_type
    add_column :repos, :name, :string, :after => :url_type

    Repo.all.each do |repo|
      repo.update_name_and_branch
    end
  end
end
