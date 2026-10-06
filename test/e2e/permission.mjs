// The plugin's permission "Edit inline" (issues_inline_edit, project module Issue tracking):
// shown in the roles' permission report next to the core issue permissions, managed by an
// administrator only.
import { e2e } from '../../.codex/e2e/lib.mjs';

const t = await e2e('permission');

await t.login('admin');
await t.go('/roles/permissions');
await t.sudo();
const row = t.page.locator('table.permissions tr', { hasText: 'Edit inline' });
if (await row.count() !== 1) t.problems.push('"Edit inline" is not in the permissions report');
const header = await t.page.locator('table.permissions thead').innerText();
const roles = header.split(/\t|\n/).map(s => s.trim()).filter(Boolean);
const checked = await row.locator('input[type=checkbox]').evaluateAll(cs => cs.map(c => c.checked));
const byRole = Object.fromEntries(roles.slice(-checked.length).map((r, i) => [r, checked[i]]));
if (!byRole['E2E full']) t.problems.push('"E2E full" does not have the permission');
if (byRole['Developer'] || byRole['Reporter']) t.problems.push(`Developer/Reporter have the permission: ${JSON.stringify(byRole)}`);
await row.scrollIntoViewIfNeeded();
await t.shot('report', `"Edit inline" in the Issue tracking block of the permissions report: ${Object.entries(byRole).filter(([, v]) => v).map(([k]) => k).join(', ')}`, { full: false });

await t.login('manager');
await t.go('/roles/permissions', { status: 403 });
await t.shot('manager-refused', 'Only an administrator manages the permission (403 for a project manager)');

await t.done();
