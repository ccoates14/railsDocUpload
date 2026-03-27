require "test_helper"
require "stringio"

class ContentItemsControllerTest < ActionDispatch::IntegrationTest
  class FakeBucket
    def create_file(*)
      true
    end
  end

  class FakeStorage
    def bucket(*)
      FakeBucket.new
    end
  end

  setup do
    @user = User.create!(email: "upload@example.com", password: "password123")
    sign_in @user
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
  end

  test "upload enqueues extraction job" do
    file = Rack::Test::UploadedFile.new(StringIO.new("hello world"), "text/plain", original_filename: "hello.txt")

    Google::Cloud::Storage.stub :new, FakeStorage.new do
      assert_enqueued_with(job: ExtractContentItemTextJob) do
        post content_items_path, params: { content_item: { file: file } }
      end
    end

    assert_redirected_to root_path
    assert_equal "pending", ContentItem.last.extraction_status
  end

  test "reindex requeues failed extraction" do
    content_item = ContentItem.create!(
      user: @user,
      name: "report.pdf",
      s3_key: "uploads/1/report.pdf",
      extraction_status: :failed,
      extraction_error: "Unsupported file type for text extraction."
    )

    assert_enqueued_with(job: ExtractContentItemTextJob, args: [ content_item.id ]) do
      post reindex_content_item_path(content_item)
    end

    content_item.reload
    assert_equal "pending", content_item.extraction_status
    assert_nil content_item.extraction_error
    assert_redirected_to root_path
  end
end
