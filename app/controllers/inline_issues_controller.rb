class InlineIssuesController < ApplicationController

  if Rails::VERSION::MAJOR >= 5
    before_action :find_project, :only => [:edit_multiple, :update_multiple]
    before_action :retrieve_query, :get_ids_before_edit, :only => [:edit_multiple]
    before_action :get_ids_before_update, :only => [:update_multiple]
    before_action :find_projects, :authorize, :only => [:edit_multiple, :update_multiple]
  else
    before_filter :find_project, :only => [:edit_multiple, :update_multiple]
    before_filter :retrieve_query, :get_ids_before_edit, :only => [:edit_multiple]
    before_filter :get_ids_before_update, :only => [:update_multiple]
    before_filter :find_projects, :authorize, :only => [:edit_multiple, :update_multiple]
  end

  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  include InlineIssuesHelper

  def edit_multiple
    @back_url = params[:back_url] || (@project ? project_issues_path(@project) : nil)
    sort = params[:sort] || [['id', 'desc']]
    @query ||= IssueQuery.new(name: '_', project: @project)

    description_column = @query.columns.find { |c| c.name == :description }
    @query_inline_columns = description_column ? @query.inline_columns.insert(1, description_column) : @query.inline_columns
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : sort)
    sort_update(@query.sortable_columns)

    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      @limit = per_page_option
      @issue_count = @query.issue_count
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset ||= @issue_pages.offset

      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                              :order => sort_clause,
                              :offset => @offset,
                              :limit => @limit,
                              :conditions => inline_edit_condition)

      @ids = @issues.map(&:id)
      @issue_count_by_group = issue_count_by_group
      @priorities = IssuePriority.active
    else
      flash[:error] = l('label_no_issues_selected')
      redirect_back_or_default params[:back_url] and return
    end

     @update_url = @project ? update_multiple_inline_issues_path(:project_id => @project) : update_multiple_inline_issues_path(:ids => @ids)
  rescue ActiveRecord::RecordNotFound
    render_404
  rescue Query::StatementInvalid
    flash[:error] = l('label_no_issues_selected')
    redirect_back_or_default params[:back_url]
  end

  def update_multiple
    # Extract the issue IDs from the params[:issues] keys
    issue_ids = params[:issues].keys

    # Find the issues based on those IDs
    @issues = Issue.where(id: issue_ids)
    raise ActiveRecord::RecordNotFound if @issues.empty?

    @projects = @issues.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1

    allow_edit_done_ratio = Setting.parent_issue_done_ratio != 'derived'
    allow_edit_dates = Setting.parent_issue_dates != 'derived'
    allow_edit_priority = Setting.parent_issue_priority != 'derived'

    # Perform issue updates
    errors = []
    @issues.each do |issue|
      issue.reload # To avoid stale issues

      # Check if the issue is a parent issue (has children)
      if issue.children.any? # Controleer of het een parent-taak is
        attribute_hash = params[:issues][issue.id.to_s].to_unsafe_hash

        # Block done_ratio if automatic calculation is enabled for parent tasks
        attribute_hash.delete('done_ratio') unless allow_edit_done_ratio

        # Block dates if automatic calculation is enabled for parent tasks
        unless allow_edit_dates
          attribute_hash.delete('start_date')
          attribute_hash.delete('due_date')
        end

        # Block priority if automatic calculation is enabled for parent tasks
        attribute_hash.delete('priority_id') unless allow_edit_priority

      else
        # If it's not a parent issue, update all fields as normal
        attribute_hash = params[:issues][issue.id.to_s].to_unsafe_hash
      end

      # Perform the update
      unless issue.update(attribute_hash)
        errors += issue.errors.full_messages.map { |m| l(:label_issue) + " #{issue.id}: " + m }
      end
    end

    if errors.present?
      flash[:error] = errors.to_sentence
    end
    redirect_back_or_default @back_url
  end

  private

  def get_ids_before_edit
    @ids = []
    if params[:ids].present?
      if params[:ids].class.name == "Array"
        @ids = params[:ids]
      elsif params[:ids].class.name == "String"
        @ids = params[:ids].split(" ")
      end
    else
      @ids = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version]).map(&:id)
    end
    @ids
  end

  def get_ids_before_update
    @ids = []
    if params[:ids].present?
      if params[:ids].class.name == "Array"
        @ids = params[:ids]
      elsif params[:ids].class.name == "String"
        @ids = params[:ids].split(" ")
      end
    end
    @ids
  end

  def find_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
    # @projects = params[:projects_id].present? ? Project.find(params[:projects_id]) : (params[:ids].present? ? Issue.find(params[:ids]).map(&:project_id).uniq : nil)
  end

  def find_projects
    @projects = @ids ? Issue.find(@ids).map(&:project).uniq : nil
  end

  # Returns the issue count by group or nil if query is not grouped
  def issue_count_by_group
    r = nil
    if @query.grouped?
      begin
        # Rails3 will raise an (unexpected) RecordNotFound if there's only a nil group value
        r = Issue.visible.
            joins(:status, :project).
            where(@query.statement).
            joins(joins_for_order_statement(@query.group_by_statement)).
            group(@query.group_by_statement).
            where(inline_edit_condition).
            count
      rescue ActiveRecord::RecordNotFound
        r = {nil => @query.issue_count}
      end
      c = @query.group_by_column
      if c.is_a?(QueryCustomFieldColumn)
        r = r.keys.inject({}) { |h, k| h[c.custom_field.cast_value(k)] = r[k]; h }
      end
    end
    r
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Additional joins required for the given sort options
  def joins_for_order_statement(order_options)
    joins = []

    if order_options
      if order_options.include?('authors')
        joins << "LEFT OUTER JOIN #{User.table_name} authors ON authors.id = #{queried_table_name}.author_id"
      end
      order_options.scan(/cf_\d+/).uniq.each do |name|
        column = @query.available_columns.detect { |c| c.name.to_s == name } # Use @query.available_columns
        join = column && column.custom_field.join_for_order_statement
        joins << join if join
      end
    end

    joins.any? ? joins.join(' ') : nil
  end

end
