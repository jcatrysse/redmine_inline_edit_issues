module InlineIssuesHelper
  include CustomFieldsHelper
  include ProjectsHelper

  def inline_project_id
    @project.present? ? @project.id : ""
  end

  def column_form_content(column, issue, f)
    if column.class.name == "QueryCustomFieldColumn"
      custom_field_values = issue.editable_custom_field_values
      value = custom_field_values.detect { |cfv| cfv.custom_field_id == column.custom_field.id }
      custom_field_tag :issues, value, issue, f if value.present?
    else
      case column.name
      when :tracker
        f.select :tracker_id, issue.project.trackers.collect { |t| [t.name, t.id] }
      when :status
        f.select :status_id, issue.new_statuses_allowed_to.collect { |p| [p.name, p.id] }
      when :priority
        f.select :priority_id, @priorities.collect { |p| [p.name, p.id] }
      when :subject
        f.text_field :subject, size: 20
      when :assigned_to
        f.select :assigned_to_id, principals_options_for_select(issue.assignable_users, issue.assigned_to), :include_blank => true
      when :urgency_id
        if defined?(RedmineItilPriority) && RedmineItilPriority.settings_for(issue.project, issue.tracker)
          f.select :urgency_id, [["", ""]] + RedmineItilPriority.urgency_options(issue.project, issue.tracker)
        else
          column_content(column, issue)
        end
      when :impact_id
        if defined?(RedmineItilPriority) && RedmineItilPriority.settings_for(issue.project, issue.tracker)
          f.select :impact_id, [["", ""]] + RedmineItilPriority.impact_options(issue.project, issue.tracker)
        else
          column_content(column, issue)
        end
      when :estimated_hours
        f.text_field :estimated_hours, size: 3
      when :start_date
        f.date_field(:start_date, size: 8) +
            calendar_for('issues_' + issue.id.to_s + '_start_date')
      when :due_date
        f.date_field(:due_date, size: 8) +
            calendar_for('issues_' + issue.id.to_s + '_due_date')
      when :done_ratio
        f.select :done_ratio, ((0..10).to_a.collect { |r| ["#{r * 10} %", r * 10] })
      when :is_private
        f.check_box :is_private
      when :description
        f.text_area :description
      when :category
        f.select :category_id, [["", ""]] + issue.project.issue_categories.collect { |t| [t.name, t.id] }
      when :fixed_version
        f.select :fixed_version_id, [["", ""]] + issue.project.versions.collect { |t| [t.name, t.id] }
      else
        column_content(column, issue)
      end
    end
  end

  def column_display_text(column, issue)
    column_content(column, issue)
  end

  def format_column_value(value)
    case value.class.name
    when 'Time'
      format_time(value)
    when 'Date'
      format_date(value)
    when 'Float'
      sprintf "%.2f", value
    when 'TrueClass'
      l(:general_text_Yes)
    when 'FalseClass'
      l(:general_text_No)
    else
      if value.respond_to?(:name)
        h(value.name)
      elsif value.respond_to?(:title)
        h(value.title)
      else
        h(value)
      end
    end
  end

  def column_total(column, issues)
    case column.name
    when :estimated_hours
      totalEstHours(issues)
    when :spent_hours
      totalSpentHours(issues)
    end
  end

  def group_column_total(column, issues, group)
    case column.name
    when :estimated_hours
      totalGroupEstHours(issues, group)
    when :spent_hours
      totalGroupSpentHours(issues, group)
    end
  end

  def inline_edit_condition
    cond = "issues.id in (#{@ids.map { |i| i.to_i }.join(',')})"
  end

  def group_class_name(group)
    begin
      if group.present?
        # strip out white spaces from the group name
        "group_" + group.name.gsub(/\s+/, "")
      else
        ""
      end
    rescue
      ""
    end
  end

  def group_total_name(group, column)
    if group.present? && column.present?
      "#{group_class_name(group)}_total_#{column.name}"
    else
      ""
    end
  end

  private

  def totalEstHours(issues)
    estTotal = 0
    issues.each { |i| estTotal += i.estimated_hours if i.estimated_hours.present? }
    sprintf "%.2f", estTotal
  end

  def totalSpentHours(issues)
    spentTotal = 0
    issues.each { |i| spentTotal += i.spent_hours if i.spent_hours.present? }
    sprintf "%.2f", spentTotal
  end

  def totalGroupEstHours(issues, group)
    estTotal = 0
    issues.each do |i|
      if i.estimated_hours.present? && @query.group_by_column.value(i) == group
        estTotal += i.estimated_hours
      end
    end
    sprintf "%.2f", estTotal
  end

  def totalGroupSpentHours(issues, group)
    spentTotal = 0
    issues.each do |i|
      if i.spent_hours.present? && @query.group_by_column.value(i) == group
        spentTotal += i.spent_hours
      end
    end
    sprintf "%.2f", spentTotal
  end


  #####
  # Return custom field html tag corresponding to its format
  #####
  def custom_field_tag(name, custom_value, issue, _f)
    custom_field = custom_value.custom_field
    field_name = "#{name}[#{issue.id}][custom_field_values][#{custom_field.id}]"
    field_name << "[]" if custom_field.multiple?
    field_id = "#{name}_#{issue.id}_custom_field_values_#{custom_field.id}"

    css = custom_field.css_classes
    placeholder = custom_field.description
    placeholder&.tr!("\n", " ") if custom_field.field_format != "text"
    data = nil
    if custom_field.full_text_formatting?
      css += " wiki-edit"
      data = { :auto_complete => true }
    end

    tag = custom_field.format.edit_tag(
      self,
      field_id,
      field_name,
      custom_value,
      :class => css,
      :placeholder => placeholder,
      :data => data
    )

    if custom_field.field_format == "sql_search"
      params_map = {}
      if custom_field.respond_to?(:form_params) && custom_field.form_params.present?
        params_map = Hash[
          custom_field.form_params.to_s.each_line.map do |str|
            key, value = str.split("=", 2)
            next unless key && value
            adjusted = value.gsub("$('#issue_custom_field_values_#{custom_field.id}')", "$('##{field_id}')")
            [key.strip, adjusted.strip]
          end.compact
        ]
      end

      options_map = {
        search_by_click: custom_field.respond_to?(:search_by_click) ? (custom_field.search_by_click || 0) : 0,
        strict_selection: custom_field.respond_to?(:strict_selection) ? (custom_field.strict_selection || 0) : 0,
        strict_error_message: custom_field.respond_to?(:strict_error_message) ? (custom_field.strict_error_message || 'it is not valid value') : 'it is not valid value'
      }

      tag << javascript_tag(
        "observeSqlField('#{field_id}', '#{Redmine::Utils.relative_url_root}/custom_sql_search/search?project_id=#{issue.project_id}&issue_id=#{issue.id}&custom_field_id=#{custom_field.id}', #{params_map.to_json}, #{options_map.to_json})"
      )
    end

    tag
  end

end
