# Data for test/e2e_together/geoxyz_plugins.mjs: run after .codex/e2e/seed.rb and
# test/e2e/seed.rb on a Redmine that also has redmine_itil_priority and
# redmine_depending_custom_fields (see the plan, "Together"). Idempotent.
User.current = User.find_by(login: 'admin')
project = Project.find_by!(identifier: 'e2e-project')
project.enable_module!(:itil_priority) if Redmine::AccessControl.available_project_modules.include?(:itil_priority)

def together_field(name, attrs)
  field = IssueCustomField.find_by(name: name) || IssueCustomField.new(name: name)
  field.attributes = { is_for_all: true, visible: true, editable: true }.merge(attrs)
  field.trackers = Tracker.all
  field.save!
  field
end

country = together_field('E2E country', field_format: 'depending_list', possible_values: %w[BE NL])
together_field('E2E city', field_format: 'depending_list', possible_values: %w[Gent Brussel Amsterdam],
                           parent_custom_field_id: country.id.to_s,
                           value_dependencies: { 'BE' => %w[Gent Brussel], 'NL' => %w[Amsterdam] })
xuser = together_field('E2E extended user', field_format: 'extended_user')
xuser.format_store['show_active'] = '1'
xuser.save!

puts "Together seed: itil_priority #{project.module_enabled?(:itil_priority) ? 'on' : 'off'}, " \
     "#{IssueCustomField.where(field_format: %w[depending_list extended_user]).count} depending/extended fields"
