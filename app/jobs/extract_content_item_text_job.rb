require "google/cloud/storage"

class ExtractContentItemTextJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(content_item_id)
    content_item = ContentItem.find(content_item_id)
    content_item.update!(extraction_status: :processing, extraction_error: nil)

    file = bucket.file(content_item.s3_key)
    unless file
      content_item.update!(extraction_status: :failed, extracted_text: nil, extraction_error: "File not found in storage.")
      return
    end

    extraction_result = ContentItemTextExtractor.new(
      file_bytes: file.download.string,
      content_type: file.content_type,
      filename: content_item.name
    ).extract

    if extraction_result[:error].present?
      content_item.update!(
        extraction_status: :failed,
        extracted_text: extraction_result[:text],
        extraction_error: extraction_result[:error]
      )
      return
    end

    content_item.update!(
      extraction_status: :succeeded,
      extracted_text: extraction_result[:text],
      extraction_error: nil
    )
  rescue StandardError => e
    content_item&.update!(extraction_status: :failed, extraction_error: "Extraction failed: #{e.class}")
    Rails.logger.error("ExtractContentItemTextJob failed for content_item_id=#{content_item_id}: #{e.class} #{e.message}")
    raise
  end

  private

  def bucket
    storage = Google::Cloud::Storage.new(
      project_id: ENV["GOOGLE_CLOUD_PROJECT"],
      credentials: ENV["GOOGLE_CLOUD_KEYFILE"]
    )
    storage.bucket(ENV["GOOGLE_CLOUD_BUCKET"])
  end
end
