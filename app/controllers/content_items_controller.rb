require 'google/cloud/storage'

class ContentItemsController < ApplicationController
  def create
    uploaded_file = content_item_params[:file]

    unless uploaded_file.present?
      redirect_to root_path, alert: "Please choose a file to upload."
      return
    end

    content_item = current_user.content_items.new(
      name: content_item_params[:name].presence || uploaded_file.original_filename,
      s3_key: generate_key(uploaded_file)
    )

    if content_item.save
      upload_to_google_cloud_bucket(uploaded_file, content_item.s3_key)
      begin
        ExtractContentItemTextJob.perform_later(content_item.id)
        redirect_to root_path, notice: "File uploaded successfully. Text extraction has started."
      rescue StandardError => e
        Rails.logger.error("Unable to enqueue ExtractContentItemTextJob for content_item_id=#{content_item.id}: #{e.class} #{e.message}")
        redirect_to root_path, notice: "File uploaded successfully, but text extraction could not be started."
      end
    else
      redirect_to root_path, alert: content_item.errors.full_messages.to_sentence
    end
  end

  def download
    content_item = current_user.content_items.find(params[:id])
    storage = Google::Cloud::Storage.new(
      project_id: ENV['GOOGLE_CLOUD_PROJECT'],
      credentials: ENV['GOOGLE_CLOUD_KEYFILE']
    )
    bucket = storage.bucket(ENV['GOOGLE_CLOUD_BUCKET'])
    file = bucket.file(content_item.s3_key)
    if file
      send_data file.download.string, filename: content_item.name, type: file.content_type
    else
      redirect_to root_path, alert: "File not found."
    end
  end

  def reindex
    content_item = current_user.content_items.find(params[:id])
    content_item.update!(extraction_status: :pending, extraction_error: nil)
    ExtractContentItemTextJob.perform_later(content_item.id)
    redirect_to root_path, notice: "Text extraction has been requeued."
  rescue StandardError => e
    Rails.logger.error("Unable to requeue ExtractContentItemTextJob for content_item_id=#{params[:id]}: #{e.class} #{e.message}")
    redirect_to root_path, alert: "Unable to requeue text extraction."
  end

  private

  def content_item_params
    params.require(:content_item).permit(:name, :file, :parent_id)
  end

  def generate_key(uploaded_file)
    extension = File.extname(uploaded_file.original_filename)
    "uploads/#{current_user.id}/#{SecureRandom.uuid}#{extension}"
  end

  def upload_to_google_cloud_bucket(uploaded_file, key)
    storage = Google::Cloud::Storage.new(
      project_id: ENV['GOOGLE_CLOUD_PROJECT'],
      credentials: ENV['GOOGLE_CLOUD_KEYFILE']
    )
    bucket = storage.bucket(ENV['GOOGLE_CLOUD_BUCKET'])
    bucket.create_file(uploaded_file.tempfile, key, content_type: uploaded_file.content_type)
  end
end
