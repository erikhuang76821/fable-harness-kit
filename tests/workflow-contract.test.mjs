// fable-emu.js 的契約測試(node --test)
// 原理:把 workflow 原始碼包成 async 函式,注入 stub 的 agent/parallel/log/budget 完整執行。
//
// ⚠ stub 忠實度聲明(防「測試替身自嗨」):stub 只模擬 harness 已文件化的語意——
//   agent() 錯誤時「回傳 null」或「throw」(兩種都真實存在,2026-07-06 實測 scribe 就吃到 throw);
//   parallel() 的 thunk 出錯 resolve 為 null、絕不 reject;schema 驗證在工具層(stub 直接回合規物件)。
//   stub 沒模擬的(重試、effort、真實模型行為)由 scripts/canary.ps1 端到端金絲雀補位——兩層互證,缺一不可。

import { test } from 'node:test'
import assert from 'node:assert'
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..')
const SRC = readFileSync(path.join(ROOT, '.claude', 'workflows', 'fable-emu.js'), 'utf8')
  .replace('export const meta', 'const meta')
const CONTRACT = JSON.parse(readFileSync(path.join(ROOT, '.claude', 'status-contract.json'), 'utf8'))

// ---------- stub 工廠:依 label 前綴路由,scenario 以 overrides 覆蓋 ----------
function makeStubs(overrides = {}) {
  const record = { logs: [], labels: [] }
  const D = {
    understand: () => ({
      restatement: '重述任務', higher_goal: '上層目標', framing_critique: '無',
      options: [
        { name: 'A 案', optimizes_for: '快', sketch: 's', tradeoffs: 't' },
        { name: 'B 案', optimizes_for: '穩', sketch: 's', tradeoffs: 't' },
      ],
      recommended_option: 'A 案', recommendation_reason: '理由', decision_gate: 'proceed',
      reversible_default: '', complexity: 'standard', notes_for_executors: '', process_mismatch: '無',
      definition_of_done: ['測試全綠'], assumptions: [], interpretations: [],
      files_in_scope: ['calc.py'], out_of_scope: [], blocking_questions: [],
    }),
    scribe: () => ({ written: true, files: [] }),
    plan: () => ({
      steps: [
        { id: 1, action: '改 calc', files: ['calc.py'], verification: '跑測試', risk: '低', risk_level: 'low' },
        { id: 2, action: '改 api', files: ['api.py'], verification: '跑測試', risk: '高', risk_level: 'high' },
      ], riskiest_step: 2,
    }),
    replan: () => ({ steps: [{ id: 10, action: '重排後步驟', verification: '跑測試', risk: '低', risk_level: 'low' }] }),
    step: () => ({ status: 'done', summary: '完成', verification_output: '3 passed, exit 0', deviation: '', plan_invalidated: false, invalidation_reason: '' }),
    verify: () => ({ refuted: false, reason: 'ok' }),
    reviewCodex: () => ({ available: true, echo: '複述:審查本次工作區變更是否符合完成定義', approved: true, findings: [] }),
    reviewAgy: () => ({ available: true, echo: '複述:審查本次工作區變更的回歸風險面', approved: true, findings: [] }),
    panel: () => ({ echo: '複述:以人格審查團身分審查本次工作區變更', approved: true, findings: [] }),
    arbitrate: () => ({ is_real: false, reason: '查證後非真問題' }),
    scopeAudit: () => ({ echo: '複述:對照宣告清單稽核變更檔案', out_of_scope: [] }),
    fix: () => ({ status: 'done', summary: 'fixed', verification_output: 'PASS', deviation: '', plan_invalidated: false }),
    refix: () => ({ refuted: false, reason: 'ok' }),
    completeness: () => ({ gaps: [] }),
    retro: () => ({ process_waste: [], kit_suggestions: [], candidate_rules: [] }),
    insight: () => ({ plan_verdict: 'sound', insights: [] }),
    maverick: () => '異端報告',
  }
  const o = Object.assign({}, D, overrides)

  const agent = async (prompt, opts = {}) => {
    const label = opts.label || ''
    record.labels.push(label)
    if (opts.phase === 'Log') return o.scribe(prompt, opts)
    if (label === 'understand') return o.understand(prompt, opts)
    if (label === 'replan') return o.replan(prompt, opts)
    if (label.startsWith('plan')) return o.plan(prompt, opts)
    if (label === 'insight') return o.insight(prompt, opts)
    if (label === 'maverick') return o.maverick(prompt, opts)
    if (label.startsWith('step')) return o.step(prompt, opts, label)
    if (label.startsWith('verify')) return o.verify(prompt, opts, label)
    if (label === 'scope-audit') return o.scopeAudit(prompt, opts)
    if (label.startsWith('review:codex')) return o.reviewCodex(prompt, opts)
    if (label.startsWith('review:agy')) return o.reviewAgy(prompt, opts)
    if (label.startsWith('review:')) return o.panel(prompt, opts, label)
    if (label.startsWith('arbitrate')) return o.arbitrate(prompt, opts)
    if (label.startsWith('fix')) return o.fix(prompt, opts)
    if (label.startsWith('refix')) return o.refix(prompt, opts)
    if (label === 'completeness') return o.completeness(prompt, opts)
    if (label === 'retro') return o.retro(prompt, opts)
    throw new Error(`stub 未覆蓋的 label:${label}(fable-emu 新增了呼叫點?請補 stub 路由)`)
  }
  // parallel 語意:thunk 出錯 resolve 為 null,絕不 reject(與 harness 文件一致)
  const parallel = thunks => Promise.all(thunks.map(t => Promise.resolve().then(t).catch(() => null)))
  const budget = { total: null, spent: () => 0, remaining: () => Infinity }
  const log = m => record.logs.push(String(m))
  const phase = () => {}
  return { agent, parallel, budget, log, phase, record }
}

async function run(argsVal, overrides) {
  const s = makeStubs(overrides)
  const fn = new Function('args', 'budget', 'agent', 'parallel', 'pipeline', 'phase', 'log', 'workflow',
    `return (async () => {\n${SRC}\n})()`)
  const result = await fn(argsVal, s.budget, s.agent, s.parallel, null, s.phase, s.log, null)
  return { result, record: s.record }
}

const TASK = { task: '修復 calc 模組使測試全綠' }

// ---------- 情境 ----------

test('happy path:全綠走到 done,跨模型單評', async () => {
  const { result } = await run(TASK)
  assert.equal(result.status, 'done')
  assert.equal(result.cross_review.mode, 'cross-model')
  assert.equal(result.cross_review.reviewers, 1)
  assert.equal(result.remaining_gaps.length, 0)
})

test('scribe 每次都 throw:落盤全滅但 workflow 必須活著走到 done(2026-07-06 滅團 bug 回歸鎖)', async () => {
  const { result, record } = await run(TASK, {
    scribe: () => { throw new Error('haiku 幻覺:我已呼叫過 StructuredOutput') },
  })
  assert.equal(result.status, 'done')
  assert.ok(record.logs.some(l => l.includes('紀錄員 agent 失敗')), '必須留下落盤失敗 log')
})

test('審查者合法省略 approved:不得整份誤棄(2026-07-06 誤棄 bug 回歸鎖)', async () => {
  const { result } = await run(TASK, {
    reviewCodex: () => ({ available: true, echo: '複述:審查本次工作區變更', findings: [{ file: 'a.py', summary: '小瑕疵', severity: 'minor' }] }),
  })
  assert.equal(result.status, 'done')
  assert.equal(result.cross_review.mode, 'cross-model', 'approved 缺省不得觸發降級')
  assert.equal(result.cross_review.reviewers, 1)
})

test('審查者缺 echo:驗收不過 → 正確降級人格團,而非直接阻斷', async () => {
  const { result } = await run(TASK, {
    reviewCodex: () => ({ available: true }),
    reviewAgy: () => ({ available: true }),
  })
  assert.equal(result.status, 'done')
  assert.equal(result.cross_review.mode, 'same-family-panel')
  assert.ok(result.cross_review.degradation_note, '降級必須留誠實註記')
})

test('全部審查管道失敗:硬阻斷 review_unavailable,不得靜默完成', async () => {
  const { result } = await run(TASK, {
    reviewCodex: () => ({ available: false }),
    reviewAgy: () => ({ available: false }),
    panel: () => { throw new Error('人格團也滅') },
  })
  assert.equal(result.status, 'review_unavailable')
})

test('process_mismatch 回「無。<解釋>」:不得誤觸安全閥短路(2026-07-06 金絲雀 bug 回歸鎖)', async () => {
  const { result } = await run(TASK, {
    understand: () => ({
      restatement: 'r', higher_goal: 'g', framing_critique: '無',
      options: [{ name: 'A', optimizes_for: 'x', sketch: 's', tradeoffs: 't' }, { name: 'B', optimizes_for: 'y', sketch: 's', tradeoffs: 't' }],
      recommended_option: 'A', recommendation_reason: 'r', decision_gate: 'proceed', reversible_default: '',
      complexity: 'trivial', notes_for_executors: '',
      process_mismatch: '無。任務雖 trivial,但使用者明示維持完整管線,故不走 mismatch。',
      definition_of_done: ['測試全綠'], assumptions: [], interpretations: [], files_in_scope: ['calc.py'],
      out_of_scope: [], blocking_questions: [],
    }),
  })
  assert.equal(result.status, 'done', '「無。解釋」語意上是無 mismatch,必須走完管線')
})

test('process_mismatch 有真實原因:正確短路上報', async () => {
  const { result } = await run(TASK, {
    understand: () => ({
      restatement: 'r', higher_goal: 'g', framing_critique: '無',
      options: [{ name: 'A', optimizes_for: 'x', sketch: 's', tradeoffs: 't' }, { name: 'B', optimizes_for: 'y', sketch: 's', tradeoffs: 't' }],
      recommended_option: 'A', decision_gate: 'proceed', reversible_default: '',
      complexity: 'standard', process_mismatch: '線上事故需即時止血,不適合五階段流程',
      definition_of_done: ['d'], assumptions: [], files_in_scope: [], blocking_questions: [],
    }),
  })
  assert.equal(result.status, 'process_mismatch')
})

test('blocking_questions:正確早退 needs_user_input', async () => {
  const { result } = await run(TASK, {
    understand: () => Object.assign(makeStubs().agent && {}, {
      restatement: 'r', higher_goal: 'g', framing_critique: '無',
      options: [{ name: 'A', optimizes_for: 'x', sketch: 's', tradeoffs: 't' }, { name: 'B', optimizes_for: 'y', sketch: 's', tradeoffs: 't' }],
      recommended_option: 'A', decision_gate: 'proceed', reversible_default: '', complexity: 'standard',
      process_mismatch: '無', definition_of_done: ['d'], assumptions: [], files_in_scope: [],
      blocking_questions: ['規格來源是哪份文件?'],
    }),
  })
  assert.equal(result.status, 'needs_user_input')
  assert.equal(result.questions.length, 1)
})

test('計畫前提失效一次:重規劃後完成,replans=1', async () => {
  let firstTry = true
  const { result } = await run(TASK, {
    step: (p, o, label) => {
      if (label.startsWith('step1') && firstTry) {
        firstTry = false
        return { status: 'done', summary: 'x', verification_output: 'x', plan_invalidated: true, invalidation_reason: '檔案結構與計畫假設不符' }
      }
      return { status: 'done', summary: '完成', verification_output: 'PASS', deviation: '', plan_invalidated: false }
    },
  })
  assert.equal(result.status, 'done')
  assert.equal(result.replans, 1)
})

test('驗證者持續駁回:耗盡修復次數後 blocked,不得硬掰成完成', async () => {
  const { result } = await run(TASK, {
    verify: () => ({ refuted: true, reason: '驗證輸出與宣稱不符' }),
  })
  assert.equal(result.status, 'blocked')
  assert.equal(result.at_step, 1)
})

test('範圍稽核:超出宣告的檔案成為 major finding 進仲裁(T4 範圍蠕變回歸鎖)', async () => {
  const { result, record } = await run(TASK, {
    scopeAudit: () => ({ echo: '複述:對照宣告清單稽核變更檔案', out_of_scope: ['rogue.py'] }),
  })
  assert.equal(result.status, 'done', '仲裁判非真問題後仍應完成')
  assert.ok(record.labels.some(l => l.startsWith('arbitrate:') && l.includes('rogue')), '超範圍檔案必須進仲裁')
})

test('範圍稽核 agent 失敗:略過不滅團,留 log', async () => {
  const { result, record } = await run(TASK, {
    scopeAudit: () => { throw new Error('稽核員陣亡') },
  })
  assert.equal(result.status, 'done')
  assert.ok(record.logs.some(l => l.includes('範圍稽核失敗')))
})

// ---------- 狀態契約對帳 ----------

test('狀態契約:fable-emu 出現的 status 字面值 ⊆ status-contract.json', () => {
  const all = new Set([...CONTRACT.terminal, ...CONTRACT.non_terminal])
  const found = new Set()
  for (const m of SRC.matchAll(/status:\s*(?:[^,\n]*\?\s*)?'([a-z_]{3,})'(?:\s*:\s*'([a-z_]{3,})')?/g)) {
    found.add(m[1]); if (m[2]) found.add(m[2])
  }
  for (const m of SRC.matchAll(/狀態(?:改為|=)\s*([a-z_]{3,})/g)) found.add(m[1])
  for (const m of SRC.matchAll(/狀態(?:改為|=)\s*\$\{[^}]*?'([a-z_]{3,})'\s*:\s*'([a-z_]{3,})'/g)) {
    found.add(m[1]); found.add(m[2])
  }
  for (const st of found) {
    assert.ok(all.has(st), `fable-emu 使用了契約外的狀態「${st}」——先改 status-contract.json`)
  }
  assert.ok(found.size >= 6, `狀態抽取異常(僅 ${found.size} 個)——抽取 regex 可能與原始碼漂移`)
})

test('狀態契約:fable-run.ps1 後備終態清單 = status-contract.json 的 terminal', () => {
  const ps = readFileSync(path.join(ROOT, 'fable-run.ps1'), 'utf8')
  const block = ps.match(/\$terminal\s*=\s*@\(([\s\S]*?)\)/)
  assert.ok(block, 'fable-run.ps1 找不到 $terminal 後備清單')
  const psList = [...block[1].matchAll(/'([a-z_]+)'/g)].map(m => m[1]).sort()
  const jsonList = [...CONTRACT.terminal].sort()
  assert.deepEqual(psList, jsonList, 'fable-run 後備清單與契約漂移——兩邊同步改')
})
