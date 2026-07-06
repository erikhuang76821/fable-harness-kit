export const meta = {
  name: 'deep-attempts',
  description: 'Tier 3 競試:N 個獨立深潛(Opus xhigh、隔離 worktree)平行解同一難題,裁判實測擇優',
  whenToUse: 'Tier 3 可驗證的難題:新問題、預期數小時、且存在客觀驗證方式(測試/基準/規格核對)。成本數學:2 個 Opus 深潛 ≈ 1 個 Fable 深潛的錢。args: {task: "難題", verify: "如何客觀驗證(指令或標準)", n: 2, context: "背景(可選)"}',
  phases: [
    { title: 'Attempts', detail: 'N 個獨立深潛,互不知情,隔離 worktree', model: 'opus' },
    { title: 'Judge', detail: '裁判到各 worktree 實測驗證,不信自報,擇優', model: 'opus' },
  ],
}

const task = args && args.task
const verify = args && args.verify
if (!task || !verify) throw new Error('用法:Workflow({name:"deep-attempts", args:{task:"...", verify:"..."}})——verify 必填:沒有客觀驗證器就不該用競試,改走深潛(見 TIER3-FRONTIER.md)')
const N = Math.max(2, Math.min((args && args.n) || 2, 3))
const extra = (args && args.context) ? `\n背景:${args.context}` : ''

// ---------- Phase 1:N 個獨立深潛(去指令化:只給目標/約束/驗收,不套 kit 條款 —— 難題入口要留白) ----------
phase('Attempts')
const attempts = (await parallel(Array.from({ length: N }, (_, i) => () =>
  agent(
    `你在一個隔離的 git worktree 裡獨立解決以下難題。另有 ${N - 1} 個平行的獨立嘗試在進行,你們互不知情——做出你自己認為最好的版本,不要保守求同。\n\n` +
    `難題:${task}${extra}\n\n` +
    `驗證標準(完成的唯一定義):${verify}\n\n` +
    `方式完全由你決定,不受任何既有流程約束。完成標準:實作 + 親自執行驗證 + 回報。\n` +
    `回報格式:你的路線一句話、驗證的真實輸出、你的 worktree 絕對路徑(pwd)、你認為這個解的最大弱點。`,
    { model: 'opus', effort: 'xhigh', isolation: 'worktree', phase: 'Attempts', label: `attempt-${i + 1}` })
))).filter(Boolean)

if (!attempts.length) return { status: 'failed', reason: '所有深潛嘗試均無回應' }
log(`${attempts.length}/${N} 個深潛完成,進入裁判實測`)

// ---------- Phase 2:裁判擇優(fresh context、實測不信自報 —— 驗證漏斗不變的鐵律) ----------
phase('Judge')
const JUDGE = {
  type: 'object',
  required: ['winner', 'scores', 'rationale'],
  properties: {
    winner: { type: 'integer', description: '1-based 勝者編號;全部不合格填 0' },
    scores: {
      type: 'array',
      items: {
        type: 'object', required: ['attempt', 'verified', 'score'],
        properties: {
          attempt: { type: 'integer' },
          verified: { type: 'boolean', description: '裁判親自到該 worktree 重跑驗證且通過才 true' },
          score: { type: 'integer', description: '0-10' },
          notes: { type: 'string' },
        },
      },
    },
    rationale: { type: 'string' },
    graft: { type: 'string', description: '值得從敗者嫁接到勝者的想法;無則空字串' },
  },
}

const judged = await agent(
  `你是裁判。${attempts.length} 個獨立嘗試解了同一道難題,各自的回報如下(各有自己的 worktree,尚未合流):\n\n` +
  attempts.map((a, i) => `===== 嘗試 ${i + 1} =====\n${String(a).slice(0, 8000)}`).join('\n\n') +
  `\n\n難題:${task}\n驗證標準:${verify}\n\n` +
  `你的工作:(1) 到每個 worktree **親自重跑驗證**,不接受任何自報結果;(2) 逐一打分(verified 是硬門檻:沒實測通過不得為勝者);(3) 選出勝者並說明;(4) 指出值得從敗者嫁接的想法。全部不合格 → winner=0。`,
  { model: 'opus', effort: 'high', schema: JUDGE, label: 'judge' })

return {
  status: judged && judged.winner > 0 ? 'winner_selected' : 'no_qualified_winner',
  n: attempts.length,
  judgement: judged || null,
  note: '勝者的 diff 在其 worktree 內,未自動合流(異端沙箱鐵律);確認後手動合入,或另行指示合入並跑最終驗證。',
}
