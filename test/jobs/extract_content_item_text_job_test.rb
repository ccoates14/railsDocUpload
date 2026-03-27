require "test_helper"

class ExtractContentItemTextJobTest < ActiveJob::TestCase
  class FakeDownload
    def string
      "hello extracted text"
    end
  end

  class FakeFile
    def content_type
      "text/plain"
    end

    def download
      FakeDownload.new
    end
  end

  class FakeBucket
    def initialize(file:)
      @file = file
    end

    def file(*)
      @file
    end
  end

  class FakeStorage
    def initialize(file:)
      @file = file
    end

    def bucket(*)
      FakeBucket.new(file: @file)
    end
  end

  test "updates extracted text and status on success" do
    user = User.create!(email: "job@example.com", password: "password123")
    content_item = ContentItem.create!(user: user, name: "hello.txt", s3_key: "uploads/1/hello.txt")

    Google::Cloud::Storage.stub :new, FakeStorage.new(file: FakeFile.new) do
      perform_enqueued_jobs do
        ExtractContentItemTextJob.perform_later(content_item.id)
      end
    end

    content_item.reload
    assert_equal "succeeded", content_item.extraction_status
    assert_equal "hello extracted text", content_item.extracted_text
    assert_nil content_item.extraction_error
  end

  test "marks failed status when extraction reports unsupported type" do
    user = User.create!(email: "job-failed@example.com", password: "password123")
    content_item = ContentItem.create!(user: user, name: "report.pdf", s3_key: "uploads/1/report.pdf")
    fake_file = Struct.new(:content_type, :download).new("application/pdf", Struct.new(:string).new("%PDF-fake"))

    ContentItemTextExtractor.stub :new, Struct.new(:extract).new({ text: nil, error: "Unsupported file type for text extraction." }) do
      Google::Cloud::Storage.stub :new, FakeStorage.new(file: fake_file) do
        perform_enqueued_jobs do
          ExtractContentItemTextJob.perform_later(content_item.id)
        end
      end
    end

    content_item.reload
    assert_equal "failed", content_item.extraction_status
    assert_equal "Unsupported file type for text extraction.", content_item.extraction_error
  end
end
