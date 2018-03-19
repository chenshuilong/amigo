require 'test_helper'

class SdkVersionReleaseControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

end
