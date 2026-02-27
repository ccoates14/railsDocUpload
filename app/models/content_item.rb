
class ContentItem < ApplicationRecord
  belongs_to :user
  belongs_to :parent, class_name: "ContentItem", optional: true
  has_many :children, class_name: "ContentItem", foreign_key: "parent_id", dependent: :destroy

  validates :name, presence: true
  validates :s3_key, presence: true
end
