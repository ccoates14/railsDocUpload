require "pdf/reader"
require "zip"
require "nokogiri"
require "stringio"

class ContentItemTextExtractor
  TEXT_CONTENT_TYPES = [
    "text/plain",
    "text/csv",
    "application/json",
    "application/xml",
    "text/xml"
  ].freeze

  def initialize(file_bytes:, content_type:, filename:)
    @file_bytes = file_bytes
    @content_type = content_type.to_s
    @filename = filename.to_s
  end

  def extract
    if pdf_file?
      extract_pdf
    elsif docx_file?
      extract_docx
    elsif text_file?
      { text: normalized_text(@file_bytes) }
    else
      { text: nil, error: "Unsupported file type for text extraction." }
    end
  rescue StandardError => e
    { text: nil, error: "Extraction failed: #{e.message}" }
  end

  private

  def extract_pdf
    reader = PDF::Reader.new(StringIO.new(@file_bytes))
    text = reader.pages.map(&:text).join("\n").strip
    return { text: text.presence } if text.present?

    { text: nil, error: "No extractable text found in PDF." }
  end

  def extract_docx
    text_nodes = []
    Zip::File.open_buffer(StringIO.new(@file_bytes)) do |zip_file|
      entry = zip_file.find_entry("word/document.xml")
      return { text: nil, error: "DOCX content is missing document.xml." } unless entry

      xml = Nokogiri::XML(entry.get_input_stream.read)
      xml.remove_namespaces!
      text_nodes = xml.xpath("//t").map(&:text)
    end

    text = normalized_text(text_nodes.join(" "))
    return { text: text } if text.present?

    { text: nil, error: "No extractable text found in DOCX." }
  end

  def normalized_text(content)
    content.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
           .scrub
           .strip
           .presence
  end

  def text_file?
    return true if @content_type.start_with?("text/")
    return true if TEXT_CONTENT_TYPES.include?(@content_type)

    [ ".txt", ".csv", ".json", ".xml", ".md", ".log" ].include?(File.extname(@filename).downcase)
  end

  def pdf_file?
    @content_type == "application/pdf" || File.extname(@filename).downcase == ".pdf"
  end

  def docx_file?
    @content_type == "application/vnd.openxmlformats-officedocument.wordprocessingml.document" || File.extname(@filename).downcase == ".docx"
  end
end
