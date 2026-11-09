/**
 * Offline smoke test: verifies the provider contract WITHOUT needing a running DSH.
 * Run with: node test/smoke.mjs
 */
import { apply, inject, name } from '../index.js'

const registered = []
const ctx = { skills: { registerProvider: (factory) => registered.push(factory) } }

apply(ctx)

if (registered.length !== 1) throw new Error('expected exactly one provider registration, got ' + registered.length)

const provider = registered[0]()
if (!provider || typeof provider.list !== 'function' || typeof provider.get !== 'function') {
  throw new Error('provider shape is wrong: need list() and get()')
}

const list = await provider.list()
if (!Array.isArray(list) || list.length !== 1) throw new Error('list() must resolve to exactly one candidate')

const candidate = list[0]
for (const key of ['name', 'description', 'invocation', 'provider', 'source', 'resourceBase', 'rank', 'locator']) {
  if (candidate[key] === undefined || candidate[key] === null || candidate[key] === '') {
    throw new Error('candidate is missing ' + key)
  }
}
if (candidate.source !== 'bundled') throw new Error('source must be "bundled"')
if (typeof candidate.rank !== 'number') throw new Error('rank must be a number')

const skill = await provider.get(candidate)
for (const key of ['name', 'description', 'content']) {
  if (!skill[key]) throw new Error('skill is missing ' + key)
}
if (skill.content.length < 1000) throw new Error('skill content looks truncated: ' + skill.content.length + ' chars')
if (skill.content.trimStart().startsWith('---')) {
  throw new Error('skill content still contains YAML frontmatter; the provider expects body-only text')
}

console.log('PASS plugin=' + name)
console.log('PASS inject=' + JSON.stringify(inject))
console.log('PASS skill=' + candidate.name + ' rank=' + candidate.rank + ' provider=' + candidate.provider + ' source=' + candidate.source)
console.log('PASS resourceBase=' + candidate.resourceBase.path)
console.log('PASS contentChars=' + skill.content.length)
