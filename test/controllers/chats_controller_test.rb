require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  test "should get negotiate" do
    get chats_negotiate_url
    assert_response :success
  end

  test "should get broadcast" do
    get chats_broadcast_url
    assert_response :success
  end
end
