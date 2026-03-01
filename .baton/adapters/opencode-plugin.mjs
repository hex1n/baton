// opencode-plugin.mjs — Baton write-lock for OpenCode
// Uses OpenCode's JS plugin system (tool.execute.before hook)
import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';

export const BatonPlugin = async ({ directory }) => ({
  "tool.execute.before": async (input, output) => {
    if (process.env.BATON_BYPASS === '1') return;
    if (!['edit', 'write', 'create'].includes(input.tool)) return;
    const filePath = input.args?.filePath || '';
    if (/\.(md|MD|markdown|mdx)$/.test(filePath)) return;
    const planName = process.env.BATON_PLAN || 'plan.md';
    let dir = directory, plan = null;
    while (true) {
      const c = join(dir, planName);
      if (existsSync(c)) { plan = c; break; }
      const p = dirname(dir);
      if (p === dir) break;
      dir = p;
    }
    if (!plan) throw new Error(`🔒 Blocked: no ${planName} found.`);
    const content = readFileSync(plan, 'utf8');
    if (!content.includes('<!-- BATON:GO -->'))
      throw new Error(`🔒 Blocked: ${planName} not unlocked.`);
  }
});
