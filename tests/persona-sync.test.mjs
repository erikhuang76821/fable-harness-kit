// 反方人格雙源同步測試(node --test)
// agents 檔(Tier 0/1 點名派用)與 fable-emu.js 內建人格團(Tier 2 降級)刻意雙源
// (workflow 沙箱不能 import 模組,無法真單源)。本測試以 persona-manifest.json 的
// 「承重條款」對帳兩邊——條款消失才紅,措辭微調不紅,避免噪音測試訓練出紅燈疲勞。

import { test } from 'node:test'
import assert from 'node:assert'
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..')
const MANIFEST = JSON.parse(readFileSync(path.join(ROOT, 'tests', 'persona-manifest.json'), 'utf8'))
const EMU = readFileSync(path.join(ROOT, '.claude', 'workflows', 'fable-emu.js'), 'utf8')

for (const p of MANIFEST.personas) {
  test(`人格同步:${p.agentFile}`, () => {
    const agentDoc = readFileSync(path.join(ROOT, p.agentFile), 'utf8')
    for (const clause of p.clauses) {
      assert.ok(agentDoc.includes(clause), `agents 檔缺承重條款「${clause}」——若刻意移除,先改 persona-manifest.json`)
      assert.ok(EMU.includes(clause), `fable-emu.js 缺承重條款「${clause}」——雙源漂移,同步修`)
    }
  })
}
