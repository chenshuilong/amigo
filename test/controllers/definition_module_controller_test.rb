require 'test_helper'

class DefinitionModuleControllerTest < ActionController::TestCase
  test "should get INDEX" do
    get :INDEX
    assert_response :success
  end

end
