class Files < ActiveRecord::Migration[8.0]
  def change
    # table containing all files and folders, with parent-child relationships, all files and folders belong to a user and are in s3
    create_table :files do |t|
      t.string :name, null: false
      t.string :s3_key, null: false
      t.boolean :is_folder, null: false, default: false
      t.references :parent, foreign_key: { to_table: :files }, index: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
