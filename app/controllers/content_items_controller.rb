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
      redirect_to root_path, notice: "File uploaded successfully."
    else
      redirect_to root_path, alert: content_item.errors.full_messages.to_sentence
    end
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
