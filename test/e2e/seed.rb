# Plugin data for the end-to-end scenarios, run by .codex/start_server.sh after the
# generic seed (.codex/e2e/seed.rb). Idempotent.
#
#   E2E full   gets core Manager's workflow (the generic seed gives it none)
#   developer  core role "Developer" in e2e-project: may edit issues, but has no inline
#              edit permission
#   editor     role "E2E full" in e2e-project only: has the permission there, but may not
#              see e2e-private
#   custom fields on every tracker of e2e-project: a user field, a list, a key/value list,
#              and a text field that the workflow makes read-only for the "E2E full" role
#   estimated hours on the open issues, for the totals

user_password = ENV.fetch('RMP_USER_PASSWORD', ENV.fetch('RMP_ADMIN_PASSWORD', 'Redmine7Test!'))
User.current = User.find_by(login: 'admin')
project = Project.find_by!(identifier: 'e2e-project')

developer = User.find_by(login: 'developer') ||
            User.new(login: 'developer', firstname: 'Developer', lastname: 'E2E', mail: 'developer@example.net')
developer.password = developer.password_confirmation = user_password
developer.must_change_passwd = false
developer.status = User::STATUS_ACTIVE
developer.save!(validate: false)
developer_role = Role.find_by!(name: 'Developer')
developer_role.remove_permission!(:issues_inline_edit) if developer_role.has_permission?(:issues_inline_edit)
unless Member.where(user_id: developer.id, project_id: project.id).exists?
  Member.create!(principal: developer, project: project, roles: [developer_role])
end

# editor: every permission (inline edit included) in e2e-project, no access to e2e-private
editor = User.find_by(login: 'editor') ||
         User.new(login: 'editor', firstname: 'Editor', lastname: 'E2E', mail: 'editor@example.net')
editor.password = editor.password_confirmation = user_password
editor.must_change_passwd = false
editor.status = User::STATUS_ACTIVE
editor.save!(validate: false)
unless Member.where(user_id: editor.id, project_id: project.id).exists?
  Member.create!(principal: editor, project: project, roles: [Role.find_by!(name: 'E2E full')])
end

def e2e_custom_field(name, attrs)
  field = IssueCustomField.find_by(name: name) || IssueCustomField.new(name: name)
  field.attributes = { is_for_all: true, visible: true, editable: true }.merge(attrs)
  field.trackers = Tracker.all
  field.save!
  field
end

e2e_custom_field('E2E user', field_format: 'user')
e2e_custom_field('E2E list', field_format: 'list', possible_values: %w[Alpha Beta Gamma])
kv = e2e_custom_field('E2E key/value', field_format: 'enumeration')
%w[North South].each_with_index do |name, i|
  kv.enumerations.find_by(name: name) || kv.enumerations.create!(name: name, position: i + 1, active: true)
end
read_only = e2e_custom_field('E2E read-only', field_format: 'string', default_value: 'fixed')

full = Role.find_by!(name: 'E2E full')
# the generic seed gives this role no workflow; take core Manager's, so statuses can change
if WorkflowTransition.where(role_id: full.id).none? && (manager_role = Role.find_by(name: 'Manager'))
  WorkflowRule.copy(nil, manager_role, nil, full)
end
Tracker.all.each do |tracker|
  IssueStatus.all.each do |status|
    WorkflowPermission.find_or_create_by!(role_id: full.id, tracker_id: tracker.id, old_status_id: status.id,
                                          field_name: read_only.id.to_s) { |w| w.rule = 'readonly' }
  end
end

parent = project.issues.find_by(subject: 'E2E assigned issue')
if parent && parent.custom_field_value(read_only).blank?
  parent.custom_field_values = { read_only.id.to_s => 'fixed by the workflow' }
  parent.save!
end

{ 'E2E unassigned issue' => 2, 'E2E related issue' => 1.5, 'E2E subtask' => 3 }.each do |subject, hours|
  issue = project.issues.find_by(subject: subject)
  next if issue.nil? || issue.estimated_hours

  issue.estimated_hours = hours
  issue.save!
end

puts "Plugin seed: developer (Developer, no inline edit), editor (e2e-project only), #{IssueCustomField.where('name LIKE ?', 'E2E %').count} custom fields"
