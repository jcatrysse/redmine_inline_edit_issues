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

  def test_edit_multiple_buttons_should_be_translated
    User.find(2).update_attribute(:language, 'nl')
    @request.session[:user_id] = 2
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 2]}
    assert_response :success
    assert_select 'input#inline_edit_reset[type=reset][value=?]', ::I18n.t(:button_reset, :locale => :nl)
  end

  def test_edit_multiple_without_permission_should_be_refused
    @request.session[:user_id] = 3
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 2]}
    assert_response 403
  end

  def test_edit_multiple_should_show_workflow_read_only_fields_as_text
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1,
                               :field_name => 'subject', :rule => 'readonly')
    @request.session[:user_id] = 2
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 2]}
    assert_response :success
    assert_select 'input[name=?]', 'issues[1][subject]', 0
    assert_select 'tr#issue-1 td.subject', :text => /Cannot print recipes/
    assert_select 'select[name=?]', 'issues[1][status_id]'
    # issue 2 is a feature request (tracker 2): the rule does not apply
    assert_select 'input[name=?]', 'issues[2][subject]'
  end

  def test_edit_multiple_should_show_the_status_as_text_without_workflow_transitions
    WorkflowTransition.where(:role_id => 1).delete_all
    @request.session[:user_id] = 2
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 2]}
    assert_response :success
    assert_select 'select[name=?]', 'issues[1][status_id]', 0
    assert_select 'tr#issue-1 td.status', :text => /New/
    assert_select 'input[name=?]', 'issues[1][subject]'
  end

  def test_edit_multiple_should_show_custom_fields_as_inputs_or_read_only_values
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1,
                               :field_name => '2', :rule => 'readonly')
    @request.session[:user_id] = 2
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 3], :set_filter => '1',
                                    :c => ['subject', 'cf_2', 'cf_8']}
    assert_response :success
    assert_select 'input[name=?]', 'issues[1][custom_field_values][2]', 0
    assert_select 'tr#issue-1 td.cf_2', :text => /125/
    assert_select 'input[name=?][value=?]', 'issues[1][custom_field_values][8]', '2009-12-01'
  end

  def test_edit_multiple_should_show_issues_whose_attributes_are_not_editable_as_text
    grant_inline_edit(2)
    Role.find(2).remove_permission!(:edit_issues)
    Role.find(2).add_permission!(:edit_own_issues)
    @request.session[:user_id] = 3
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 2]}
    assert_response :success
    assert_select 'tr#issue-1'
    assert_select 'tr#issue-1 input, tr#issue-1 select, tr#issue-1 textarea', 0
  end

  def test_edit_multiple_should_show_issues_of_a_project_without_the_permission_as_text
    # issue 5 is in subproject1, where jsmith has no role and so no inline edit permission
    @request.session[:user_id] = 2
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 5]}
    assert_response :success
    assert_select 'input[name=?]', 'issues[1][subject]'
    assert_select 'tr#issue-5'
    assert_select 'tr#issue-5 input, tr#issue-5 select, tr#issue-5 textarea', 0
  end

  def test_edit_multiple_grouped_should_render_core_group_rows
    @request.session[:user_id] = 2
    get :edit_multiple, :params => {:project_id => 'ecookbook', :ids => [1, 2, 3], :set_filter => '1',
                                    :group_by => 'tracker', :c => ['subject', 'estimated_hours']}
    assert_response :success
    assert_select 'tr.group span.expander', 2
    assert_select 'tr.group span.badge.badge-count.count', 2
    if Redmine::VERSION::MAJOR >= 6
      # core's toggleRowGroup and collapse/expand all switch the SVG icon of the expander
      assert_select 'tr.group span.expander svg use[href$=?]', '#icon--angle-down', 2
    end
    # a totals row is not a group header: collapse/expand all would look for its expander
    assert_select 'tr.inline_group_totals', 2
    assert_select 'tr.group.inline_group_totals', 0
  end

  def test_update_multiple_with_permission
    @request.session[:user_id] = 2
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :back_url => '/projects/ecookbook/issues',
                                      :issues => {'1' => {:subject => 'Changed inline'}}}
    assert_redirected_to '/projects/ecookbook/issues'
    assert_equal 'Changed inline', Issue.find(1).subject
    assert_equal 'Successful update.', flash[:notice]
  end

  def test_update_multiple_without_permission_should_be_refused
    @request.session[:user_id] = 3
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'1' => {:subject => 'Changed inline'}}}
    assert_response 403
    assert_equal 'Cannot print recipes', Issue.find(1).subject
  end

  def test_update_multiple_should_record_the_change_in_the_history
    @request.session[:user_id] = 2
    assert_difference 'Journal.count', 1 do
      put :update_multiple, :params => {:project_id => 'ecookbook',
                                        :issues => {'1' => {:subject => 'Changed inline'}}}
    end
    journal = Issue.find(1).journals.order(:id).last
    assert_equal User.find(2), journal.user
    assert_equal ['subject'], journal.details.map(&:prop_key)
  end

  def test_update_multiple_should_refuse_an_issue_the_user_cannot_see
    grant_inline_edit(1, 2)
    @request.session[:user_id] = 3
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'4' => {:subject => 'Hacked', :author_id => '3'}}}
    assert_response 403
    issue = Issue.find(4)
    assert_equal 'Issue on project 2', issue.subject
    assert_equal 2, issue.author_id
  end

  def test_update_multiple_should_save_nothing_when_one_issue_is_not_visible
    grant_inline_edit(1, 2)
    @request.session[:user_id] = 3
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'1' => {:subject => 'Changed inline'},
                                                  '4' => {:subject => 'Hacked'}}}
    assert_response 403
    assert_equal 'Cannot print recipes', Issue.find(1).subject
    assert_equal 'Issue on project 2', Issue.find(4).subject
  end

  def test_update_multiple_should_check_the_permission_on_the_project_of_the_issue
    # jsmith may inline edit in project 1 (Manager) but not in project 2 (Developer)
    @request.session[:user_id] = 2
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'4' => {:subject => 'Changed inline'}}}
    assert_response 403
    assert_equal 'Issue on project 2', Issue.find(4).subject
  end

  def test_update_multiple_should_refuse_issues_whose_attributes_are_not_editable
    grant_inline_edit(2)
    Role.find(2).remove_permission!(:edit_issues)
    Role.find(2).add_permission!(:edit_own_issues)
    @request.session[:user_id] = 3
    # issue 1 was written by jsmith, not by dlopper
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'1' => {:subject => 'Changed inline'}}}
    assert_response 403
    assert_equal 'Cannot print recipes', Issue.find(1).subject
  end

  def test_update_multiple_should_ignore_attributes_that_are_not_safe
    @request.session[:user_id] = 2
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'1' => {:subject => 'Changed inline', :author_id => '3',
                                                          :closed_on => '2001-01-01 00:00:00'}}}
    assert_response 302
    issue = Issue.find(1)
    assert_equal 'Changed inline', issue.subject
    assert_equal 2, issue.author_id
    assert_nil issue.closed_on
  end

  def test_update_multiple_should_not_assign_a_priority_that_was_not_changed
    # The form submits every visible field. A plugin that derives the priority (ITIL priority
    # from impact and urgency) takes an assigned priority for a choice of the user.
    @request.session[:user_id] = 2
    Issue.any_instance.expects(:priority_id=).never
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'1' => {:subject => 'Changed inline', :priority_id => '4'}}}
    assert_response 302
    assert_equal 'Changed inline', Issue.find(1).subject
  end

  def test_update_multiple_should_assign_a_changed_priority
    @request.session[:user_id] = 2
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'1' => {:priority_id => '5'}}}
    assert_response 302
    assert_equal 5, Issue.find(1).priority_id
  end

  def test_update_multiple_should_respect_workflow_read_only_fields
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1,
                               :field_name => 'subject', :rule => 'readonly')
    @request.session[:user_id] = 2
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'1' => {:subject => 'Changed inline', :done_ratio => '30'}}}
    assert_response 302
    issue = Issue.find(1)
    assert_equal 'Cannot print recipes', issue.subject
    assert_equal 30, issue.done_ratio
  end

  def test_update_multiple_should_show_validation_errors
    @request.session[:user_id] = 2
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :back_url => '/projects/ecookbook/issues',
                                      :issues => {'1' => {:subject => ''}}}
    assert_redirected_to '/projects/ecookbook/issues'
    assert_match /Issue 1: Subject cannot be blank/, flash[:error]
    assert_equal 'Cannot print recipes', Issue.find(1).subject
  end

  def test_update_multiple_without_issues_should_respond_with_404
    @request.session[:user_id] = 2
    put :update_multiple, :params => {:project_id => 'ecookbook'}
    assert_response 404
  end

  def test_update_multiple_with_an_unknown_issue_should_respond_with_404
    @request.session[:user_id] = 2
    put :update_multiple, :params => {:project_id => 'ecookbook',
                                      :issues => {'1' => {:subject => 'Changed inline'},
                                                  '999' => {:subject => 'Nothing'}}}
    assert_response 404
    assert_equal 'Cannot print recipes', Issue.find(1).subject
  end

  def test_update_multiple_with_a_value_that_is_not_a_set_of_attributes_should_respond_with_422
    @request.session[:user_id] = 2
    put :update_multiple, :params => {:project_id => 'ecookbook', :issues => {'1' => 'Changed inline'}}
    assert_response 422
    assert_equal 'Cannot print recipes', Issue.find(1).subject
  end

  if defined?(Webhook) # Redmine 7
    include ActiveJob::TestHelper

    def test_update_multiple_should_send_the_issue_updated_webhook_with_the_journal
      adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      Role.find(1).add_permission!(:use_webhooks)
      hook = Webhook.new(:url => 'https://example.com/hook', :user => User.find(2),
                         :projects => [Project.find(1)], :events => ['issue.updated'], :active => true)
      hook.save!(:validate => false)
      @request.session[:user_id] = 2
      with_settings :webhooks_enabled => '1' do
        assert_enqueued_jobs 1, :only => WebhookJob do
          put :update_multiple, :params => {:project_id => 'ecookbook',
                                            :issues => {'1' => {:subject => 'Changed inline'}}}
        end
      end
      hook_id, json = enqueued_jobs.detect { |job| job[:job] == WebhookJob }[:args]
      payload = ActiveSupport::JSON.decode(json)
      assert_equal hook.id, hook_id
      assert_equal 'issue.updated', payload['type']
      assert_equal 'Changed inline', payload.dig('data', 'issue', 'subject')
      assert_equal [['subject', 'Cannot print recipes', 'Changed inline']],
                   payload.dig('data', 'journal', 'details').map { |d| d.values_at('prop_key', 'old_value', 'value') }
    ensure
      ActiveJob::Base.queue_adapter = adapter
    end
  end
end
