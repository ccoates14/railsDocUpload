
class ContentItem < ApplicationRecord
  belongs_to :user
  belongs_to :parent, class_name: "ContentItem", optional: true
  has_many :children, class_name: "ContentItem", foreign_key: "parent_id", dependent: :destroy

  enum :extraction_status, {
    pending: "pending",
    processing: "processing",
    succeeded: "succeeded",
    failed: "failed"
  }, default: :pending

  validates :name, presence: true
  validates :s3_key, presence: true
end
