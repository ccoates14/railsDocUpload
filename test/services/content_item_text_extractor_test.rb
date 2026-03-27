require "test_helper"

class ContentItemTextExtractorTest < ActiveSupport::TestCase
  test "extracts text from pdf content via PDF reader" do
    fake_page = Struct.new(:text).new("invoice total")
    fake_reader = Struct.new(:pages).new([ fake_page ])

    PDF::Reader.stub :new, fake_reader do
      result = ContentItemTextExtractor.new(
        file_bytes: "%PDF-fake",
        content_type: "application/pdf",
        filename: "invoice.pdf"
      ).extract

      assert_equal "invoice total", result[:text]
      assert_nil result[:error]
    end
  end

  test "extracts text from docx xml content" do
    fake_entry = Struct.new(:get_input_stream).new(Struct.new(:read).new("<w:document><w:body><w:p><w:r><w:t>Hello DOCX</w:t></w:r></w:p></w:body></w:document>"))
    fake_zip = Struct.new(:find_entry).new(fake_entry)

    Zip::File.stub :open_buffer, ->(*, &blk) { blk.call(fake_zip) } do
      result = ContentItemTextExtractor.new(
        file_bytes: "fake-docx-bytes",
        content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        filename: "report.docx"
      ).extract

      assert_equal "Hello DOCX", result[:text]
      assert_nil result[:error]
    end
  end

  test "returns unsupported error for unknown binary file" do
    result = ContentItemTextExtractor.new(
      file_bytes: "binary",
      content_type: "application/octet-stream",
      filename: "archive.bin"
    ).extract

    assert_nil result[:text]
    assert_equal "Unsupported file type for text extraction.", result[:error]
  end
end
