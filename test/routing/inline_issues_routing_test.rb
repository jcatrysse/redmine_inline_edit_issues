require File.expand_path('../../test_helper', __FILE__)

class InlineIssuesRoutingTest < Redmine::RoutingTest
  def test_inline_issues
    should_route 'GET /inline_issues/edit_multiple' => 'inline_issues#edit_multiple'
    should_route 'GET /projects/foo/inline_issues/edit_multiple' => 'inline_issues#edit_multiple', :project_id => 'foo'
    should_route 'PUT /inline_issues/update_multiple' => 'inline_issues#update_multiple'
  end

  def test_core_project_routes_stay_with_core
    should_route 'GET /projects/foo' => 'projects#show', :id => 'foo'
    should_route 'GET /projects' => 'projects#index'
  end

  def test_no_rest_routes_without_an_action
    ['GET /inline_issues', 'GET /inline_issues/new', 'GET /inline_issues/1', 'GET /inline_issues/1/edit',
     'POST /inline_issues', 'GET /projects/foo/inline_issues', 'GET /projects/foo/inline_issues/1'].each do |request|
      method, path = request.split(' ')
      route = Rails.application.routes.recognize_path(path, :method => method.downcase.to_sym) rescue nil
      assert_not_equal 'inline_issues', route && route[:controller], "#{request} is routed"
    end
  end
end
