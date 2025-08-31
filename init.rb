# frozen_string_literal: true

require 'redmine'

Redmine::Plugin.register :redmine_inline_edit_issues do
  name 'Redmine Inline Edit Issues plugin'
  author 'Omega Code'
  description 'This plugin allows inline editing of issue details'
  version '0.0.2'
  url 'https://github.com/omegacodepl/redmine_inline_edit_issues'
  author_url 'https://github.com/omegacodepl'

  # Hook the plugin into the right places
  require File.dirname(__FILE__) + '/lib/redmine_inline_edit_issues/hooks'

  Rails.application.paths["app/overrides"] ||= []
  Rails.application.paths["app/overrides"] << File.expand_path("../app/overrides", __FILE__)

  project_module :issue_tracking do
    permission :issues_inline_edit, :inline_issues => [:edit_multiple, :update_multiple]
  end
end
