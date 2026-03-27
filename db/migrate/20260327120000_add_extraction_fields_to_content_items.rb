class AddExtractionFieldsToContentItems < ActiveRecord::Migration[8.0]
  def change
    add_column :content_items, :extracted_text, :text
    add_column :content_items, :extraction_status, :string, null: false, default: "pending"

    add_index :content_items, [ :user_id, :extraction_status ]
  end
end
