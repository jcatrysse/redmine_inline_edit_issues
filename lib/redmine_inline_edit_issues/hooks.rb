# lib/redmine_inline_edit_issues/hooks.rb
module RedmineInlineEditIssues
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_issues_context_menu_start, partial: "inline_issues/context_menu_hook"
  end
end
