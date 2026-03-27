class AddExtractionErrorToContentItems < ActiveRecord::Migration[8.0]
  def change
    add_column :content_items, :extraction_error, :string
  end
end
