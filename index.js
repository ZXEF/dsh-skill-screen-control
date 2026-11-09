/**
 * dsh-skill-screen-control - bundled skill provider (host half).
 *
 * Registers one skill, `screen-control`, whose instructions live in
 * ./skills/screen-control/SKILL.md and whose helper scripts live next to it in
 * ./skills/screen-control/scripts/.
 *
 * The provider contract is the one `@deepseek-ai/dsh-skill` expects:
 *   { name, list(): Promise<Candidate[]>, get(candidate): Promise<Skill> }
 *
 * This file intentionally imports only node builtins, so the package has no
 * runtime dependency on internal @deepseek-ai packages beyond the host itself.
 */
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

/** Cordis plugin name. */
export const name = 'dsh-skill-screen-control'

/** The skills registry service must exist before we can register a provider. */
export const inject = ['skills']

/** Rank used by the host for bundled skill roots (filesystem provider uses 600). */
const BUNDLED_RANK = 600

/** Provider id; distinct from the filesystem provider's `filesystem`. */
const PROVIDER = 'screen-control-bundle'

const SKILL_DIR = new URL('./skills/screen-control/', import.meta.url)
const BODY_URL = new URL('./skills/screen-control/SKILL.md', import.meta.url)

const RESOURCE_BASE = {
  kind: 'directory',
  path: fileURLToPath(SKILL_DIR),
}

const DESCRIPTION =
  '用「截图 -> 视觉识别 -> 模拟鼠标键盘」真实操控 Windows 桌面程序（游戏、软件、任何 GUI），' +
  '并附带一个置顶、鼠标穿透的「思考流」浮窗展示每一步的看/想/动。' +
  '当任务需要真实点击、拖动、滚轮、按键、打字，或用户要求「操作我的电脑 / 玩某个游戏 / 帮我点一下」时使用。'

const CANDIDATE = {
  name: 'screen-control',
  description: DESCRIPTION,
  invocation: {
    modelInvocable: true,
    userInvocable: true,
  },
  provider: PROVIDER,
  source: 'bundled',
  resourceBase: RESOURCE_BASE,
  rank: BUNDLED_RANK,
  locator: BODY_URL,
}

const provider = {
  name: PROVIDER,
  list: () => Promise.resolve([CANDIDATE]),
  async get(_candidate) {
    return {
      name: CANDIDATE.name,
      description: CANDIDATE.description,
      invocation: CANDIDATE.invocation,
      provider: CANDIDATE.provider,
      source: CANDIDATE.source,
      resourceBase: RESOURCE_BASE,
      content: await readFile(BODY_URL, 'utf8'),
    }
  },
}

/** Register the bundled provider on the skills registry. */
export function apply(ctx) {
  ctx.skills.registerProvider(() => provider)
}
