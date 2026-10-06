require File.expand_path('../../test_helper', __FILE__)

class InlineIssuesControllerTest < Redmine::ControllerTest
  include RedmineInlineEditIssues::TestHelper
  fixtures(*INLINE_EDIT_FIXTURES)

  def setup
    User.current = nil
    grant_inline_edit(1)
  end

  def test_edit_multiple_should_require_login
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 2]}
    assert_response 302
    assert_match %r{/login}, response.location
  end

  def test_edit_multiple_with_permission
    @request.session[:user_id] = 2
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 2]}
    assert_response :success
    assert_select 'form#inline_edit_form' do
      assert_select 'input[name=?][value=?]', 'issues[1][subject]', 'Cannot print recipes'
      assert_select 'input[name=?]', 'issues[2][subject]'
    end
  end

  def test_edit_multiple_without_permission_should_be_refused
    @request.session[:user_id] = 3
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 2]}
    assert_response 403
  end

  def test_update_multiple_with_permission
    @request.session[:user_id] = 2
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :back_url => '/projects/ecookbook/issues',
                                      :issues => {'1' => {:subject => 'Changed inline'}}}
    assert_redirected_to '/projects/ecookbook/issues'
    assert_equal 'Changed inline', Issue.find(1).subject
  end

  def test_update_multiple_without_permission_should_be_refused
    @request.session[:user_id] = 3
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'1' => {:subject => 'Changed inline'}}}
    assert_response 403
    assert_equal 'Cannot print recipes', Issue.find(1).subject
  end
end
