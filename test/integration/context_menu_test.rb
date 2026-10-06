require File.expand_path('../../test_helper', __FILE__)

class InlineEditContextMenuTest < Redmine::IntegrationTest
  include RedmineInlineEditIssues::TestHelper
  fixtures(*INLINE_EDIT_FIXTURES)

  def setup
    grant_inline_edit(1)
  end

  def test_context_menu_should_link_to_the_inline_edit_form
    log_user('jsmith', 'jsmith')
    post '/issues/context_menu', :params => {:ids => [1, 2],
                                             :back_url => '/projects/ecookbook/issues?c[]=subject&c[]=status&sort=id:desc'}
    assert_response :success
    assert_select 'a.icon-edit:not(.disabled)[href*=?]', '/projects/ecookbook/inline_issues/edit_multiple', 1 do |link|
      href = link.first['href']
      assert_include 'ids%5B%5D=1', href
      assert_include 'ids%5B%5D=2', href
      assert_include 'c%5B%5D=subject', href
      assert_include 'c%5B%5D=status', href
      assert_include 'sort=id%3Adesc', href
    end
    assert_select 'a.icon-edit', :text => 'Edit Inline'
    if Redmine::VERSION::MAJOR >= 6
      assert_select 'a.icon-edit[href*=?] svg use[href$=?]', 'inline_issues/edit_multiple', '#icon--edit'
    end
  end

  def test_context_menu_without_the_permission_should_disable_the_link
    # dlopper may edit issues in project 1 (Developer) but not inline edit them
    log_user('dlopper', 'foo')
    post '/issues/context_menu', :params => {:ids => [1, 2], :back_url => '/projects/ecookbook/issues'}
    assert_response :success
    assert_select 'a.icon-edit.disabled', :text => 'Edit Inline'
    assert_select 'a[href*=?]', 'inline_issues/edit_multiple', 0
  end

  def test_context_menu_should_survive_a_back_url_that_cannot_be_parsed
    log_user('jsmith', 'jsmith')
    ['/projects/ecookbook/issues?c[]=subject&c[x]=status', '/projects/eco cookbook/issues', '/issues?sort=%'].each do |back_url|
      post '/issues/context_menu', :params => {:ids => [1, 2], :back_url => back_url}
      assert_response :success, "back_url #{back_url}"
      assert_select 'a.icon-edit[href*=?]', 'inline_issues/edit_multiple', 1
    end
  end

  def test_context_menu_on_a_single_issue_should_not_show_the_link
    log_user('jsmith', 'jsmith')
    post '/issues/context_menu', :params => {:ids => [1], :back_url => '/projects/ecookbook/issues'}
    assert_response :success
    assert_select 'a[href*=?]', 'inline_issues/edit_multiple', 0
  end
end
