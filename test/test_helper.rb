require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

module RedmineInlineEditIssues
  module TestHelper
    # Core fixtures used by the plugin's tests:
    #   user 2 (jsmith):  project 1 [role 1 Manager], project 2 (private) [role 2 Developer]
    #   user 3 (dlopper): project 1 [role 2 Developer], no access to project 2
    INLINE_EDIT_FIXTURES = [:projects, :users, :email_addresses, :roles, :members, :member_roles,
                            :issues, :issue_statuses, :trackers, :projects_trackers, :enabled_modules,
                            :enumerations, :workflows, :versions, :issue_categories,
                            :custom_fields, :custom_values, :custom_fields_projects, :custom_fields_trackers,
                            :journals, :journal_details]

    def grant_inline_edit(*role_ids)
      Role.where(:id => role_ids).each { |role| role.add_permission!(:issues_inline_edit) }
    end
  end
end
