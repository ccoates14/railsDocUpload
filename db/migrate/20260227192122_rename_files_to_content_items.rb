class RenameFilesToContentItems < ActiveRecord::Migration[8.0]
  def change
    rename_table :files, :content_items
  end
end
