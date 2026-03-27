require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows dashboard for signed in user" do
    user = User.create!(email: "home@example.com", password: "password123")
    sign_in user

    get root_url
    assert_response :success
    assert_includes response.body, "Your Files"
  end

  test "filters user files by extracted text and name" do
    user = User.create!(email: "search@example.com", password: "password123")
    other_user = User.create!(email: "other@example.com", password: "password123")
    sign_in user

    ContentItem.create!(user: user, name: "notes.txt", s3_key: "uploads/1/a.txt", extracted_text: "budget planning")
    ContentItem.create!(user: user, name: "invoice.txt", s3_key: "uploads/1/b.txt", extracted_text: "march totals")
    ContentItem.create!(user: other_user, name: "secret.txt", s3_key: "uploads/2/c.txt", extracted_text: "budget planning")

    get root_url, params: { q: "budget" }

    assert_response :success
    assert_includes response.body, "notes.txt"
    assert_not_includes response.body, "invoice.txt"
    assert_not_includes response.body, "secret.txt"
  end
end
