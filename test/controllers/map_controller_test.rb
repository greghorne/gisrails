require 'test_helper'

class MapControllerTest < ActionController::TestCase
  test "should get show_map" do
    get :show_map
    assert_response :success
  end

end
