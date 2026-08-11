// Node-side loader: reads /data off disk and hands it to the shared content
// pipeline. The interpretation lives in content-core.js so the browser build
// runs identical code from fetched JSON.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { buildContent } from './content-core.js';

export { auditModifiers } from './content-core.js';

const HERE = dirname(fileURLToPath(import.meta.url));
const DATA = join(HERE, '..', 'data');
const read = (f) => JSON.parse(readFileSync(join(DATA, f), 'utf8'));

export const DATA_FILES = ['customers.json', 'fixtures.json', 'economy.json', 'run.json'];

/** @param {object} [overrides] tuning overrides applied on top of the JSON. */
export function loadContent(overrides = {}) {
  return buildContent({
    customers: read('customers.json'),
    fixtures: read('fixtures.json'),
    economy: read('economy.json'),
    run: read('run.json'),
  }, overrides);
}
