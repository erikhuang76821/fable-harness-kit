export const meta = {
  name: 'fable-emu',
  description: 'Opus 規劃與仲裁 + Sonnet 執行 + Codex/Agy 跨模型對抗審查:用流程強制力補齊思考維度',
  whenToUse: 'Tier 2 任務限定:跨模組 / 不可逆操作 / 使用者點名;僅限互動式 session(headless 會截斷背景 workflow,一律降 Tier 1)。args 傳 {task: "任務描述", context: "補充背景(可選)", maxRepair: 2, chosenOption: "上輪上報後使用者選定的方案名(可選)", thorough: false, maverick: false}',
  phases: [
    { title: 'Understand', detail: '重述任務、驗證假設、定義完成、複雜度分級', model: 'opus' },
    { title: 'Plan', detail: '計畫競技場(複雜度決定規模)+ 洞察代理', model: 'opus' },
    { title: 'Execute', detail: '逐步執行,風險分級驗證,計畫失效可重規劃一次', model: 'sonnet' },
    { title: 'CrossReview', detail: 'Codex 與 Agy 對抗審查,發現交 Opus 仲裁' },
    { title: 'Completeness', detail: '對照完成定義 + 重推導未言明期望' },
    { title: 'Retro', detail: '賽後檢討:流程浪費與升格規則建議', model: 'sonnet' },
    { title: 'Log', detail: '紀錄員:TASK 狀態 / 決策 / 教訓 動態落盤', model: 'haiku' },
  ],
}

// ---------- schemas:格式即強制力,缺欄位會被工具層打回重試 ----------
const UNDERSTANDING = {
  type: 'object',
  required: ['restatement', 'higher_goal', 'definition_of_done', 'assumptions', 'options', 'recommended_option', 'decision_gate', 'complexity', 'files_in_scope', 'blocking_questions'],
  properties: {
    restatement: { type: 'string', description: '用自己的話重述任務目標' },
    higher_goal: { type: 'string', description: '這個任務在服務什麼更上層的目標(往上追一層)' },
    framing_critique: { type: 'string', description: '任務的提法本身是否限制了更好的解;有就提出重述,沒有填「無」' },
    options: {
      type: 'array',
      minItems: 2,
      maxItems: 3,
      description: '2-3 個優化不同價值軸的方案(快/穩/長期優質);若確實只有單一合理路徑,第二案放你否決的次佳方案,並在其 tradeoffs 說明否決理由',
      items: {
        type: 'object', required: ['name', 'optimizes_for', 'sketch', 'tradeoffs'],
        properties: {
          name: { type: 'string' },
          optimizes_for: { type: 'string', description: '此方案優化的價值軸' },
          sketch: { type: 'string' },
          tradeoffs: { type: 'string' },
        },
      },
    },
    recommended_option: { type: 'string', description: '明確推薦其中一案,不得棄權' },
    recommendation_reason: { type: 'string' },
    decision_gate: { enum: ['proceed', 'user_should_choose'], description: '選項間差異屬戰略性或不可逆時選 user_should_choose,其餘 proceed' },
    reversible_default: { type: 'string', description: '分歧屬不可逆、但存在「可逆且立即可交付」的預設路徑時(例:先做不改語意的修復,爭議另案),寫明該路徑;此時 recommended_option 必須就是這條路徑。沒有則留空字串' },
    complexity: { enum: ['trivial', 'standard', 'complex'], description: '任務複雜度:決定計畫競技場規模與洞察代理是否出動' },
    notes_for_executors: { type: 'string', description: '給執行者的現場筆記:直覺、聞到的味道、警告 —— 把說得出口的默會知識寫下來,沒有則留空字串' },
    process_mismatch: { type: 'string', description: '僅當此任務「根本不適合」本流程(如純研究問題、線上事故止血)才填原因與建議路線;適合則填「無」。不是用來逃流程的' },
    definition_of_done: { type: 'array', items: { type: 'string' } },
    assumptions: {
      type: 'array',
      items: {
        type: 'object', required: ['claim', 'verified'],
        properties: {
          claim: { type: 'string' },
          verified: { type: 'boolean', description: '已實際讀 code 或跑指令驗證過才填 true' },
          how_verified: { type: 'string' },
        },
      },
    },
    interpretations: { type: 'array', items: { type: 'string' }, description: '需求的其他可能解讀與為何不採用' },
    files_in_scope: { type: 'array', items: { type: 'string' } },
    out_of_scope: { type: 'array', items: { type: 'string' } },
    blocking_questions: { type: 'array', items: { type: 'string' }, description: '不問使用者就無法安全動工的問題;沒有則為空陣列' },
  },
}

const PLAN = {
  type: 'object',
  required: ['steps'],
  properties: {
    steps: {
      type: 'array',
      items: {
        type: 'object', required: ['id', 'action', 'verification', 'risk', 'risk_level'],
        properties: {
          id: { type: 'integer' },
          action: { type: 'string' },
          files: { type: 'array', items: { type: 'string' } },
          verification: { type: 'string', description: '如何證明這步是對的:指令、測試、或可觀察行為' },
          risk: { type: 'string' },
          risk_level: { enum: ['low', 'high'], description: 'high:涉及不變量、跨模組、可能破壞資料;low:局部且易回退' },
          fallback: { type: 'string' },
        },
      },
    },
    riskiest_step: { type: 'integer' },
    judge_rationale: { type: 'string', description: '(競技場合成時)採納了誰的骨架、嫁接了誰的想法、否決了什麼' },
  },
}

const STEP_RESULT = {
  type: 'object',
  required: ['status', 'summary', 'verification_output', 'plan_invalidated'],
  properties: {
    status: { enum: ['done', 'blocked'] },
    summary: { type: 'string' },
    verification_output: { type: 'string', description: '驗證指令的真實輸出,禁止腦補' },
    deviation: { type: 'string', description: '與計畫不符之處;沒有則留空字串' },
    plan_invalidated: { type: 'boolean', description: '發現「不是這步做不到,而是計畫的前提錯了」才 true —— 會觸發重規劃,不是逃避這一步的藉口' },
    invalidation_reason: { type: 'string', description: 'plan_invalidated=true 時必填:哪個前提、被什麼事實推翻' },
  },
}

const VERDICT = {
  type: 'object',
  required: ['refuted', 'reason'],
  properties: {
    refuted: { type: 'boolean', description: '修改有實質問題則 true;證據不足以放行時預設 true' },
    reason: { type: 'string' },
  },
}

const REVIEW = {
  type: 'object',
  required: ['approved', 'findings'],
  properties: {
    approved: { type: 'boolean' },
    findings: {
      type: 'array',
      items: {
        type: 'object', required: ['summary', 'severity'],
        properties: {
          file: { type: 'string' },
          summary: { type: 'string' },
          severity: { enum: ['critical', 'major', 'minor'] },
        },
      },
    },
  },
}

const ARBITRATION = {
  type: 'object',
  required: ['is_real', 'reason'],
  properties: {
    is_real: { type: 'boolean', description: '實際讀 code 求證後確認是真問題才 true' },
    reason: { type: 'string' },
  },
}

const GAPS = {
  type: 'object',
  required: ['gaps'],
  properties: { gaps: { type: 'array', items: { type: 'string' } } },
}

const SCRIBE_RESULT = {
  type: 'object',
  required: ['written'],
  properties: {
    written: { type: 'boolean', description: '所有指定檔案都實際寫入成功才 true' },
    files: { type: 'array', items: { type: 'string' } },
    error: { type: 'string' },
  },
}

const INSIGHT = {
  type: 'object',
  required: ['plan_verdict', 'insights'],
  properties: {
    plan_verdict: { enum: ['sound', 'needs_revision'], description: 'needs_revision 僅在發現實質缺陷或明顯更好的路線時' },
    insights: {
      type: 'array',
      items: {
        type: 'object', required: ['observation', 'severity'],
        properties: {
          observation: { type: 'string' },
          severity: { enum: ['fundamental', 'notable', 'nice_to_know'] },
          suggestion: { type: 'string' },
        },
      },
    },
  },
}

const RETRO = {
  type: 'object',
  required: ['process_waste', 'kit_suggestions', 'candidate_rules'],
  properties: {
    process_waste: { type: 'array', items: { type: 'string' }, description: '本次 run 哪個環節浪費了(多餘驗證、無效重試、prompt 誤導)' },
    kit_suggestions: { type: 'array', items: { type: 'string' }, description: '對 workflow 腳本或 prompt 的具體修改建議' },
    candidate_rules: { type: 'array', items: { type: 'string' }, description: 'LESSONS 中重複出現、值得升格為 CLAUDE.md 條款或 invariants 的教訓' },
  },
}

// ---------- 輸入 ----------
const task = typeof args === 'string' ? args : (args && args.task)
if (!task) throw new Error('用法:Workflow({name:"fable-emu", args:{task:"..."}})')
const extra = (args && args.context) ? `\n補充背景:\n${args.context}` : ''
const MAX_REPAIR = (args && args.maxRepair) || 2

// ---------- 預算分艙:探索(競技場/洞察/異端)再貴也不能餓死驗證漏斗 ----------
// 天花板加在生成端,地板鎖在驗證端:總預算的 30% 保留給驗證與審查,探索花費不得侵入
const VERIFY_RESERVE = budget.total ? Math.floor(budget.total * 0.3) : 0
const explorationOK = () => !budget.total || budget.remaining() > VERIFY_RESERVE + 40000

// ---------- 落盤紀錄:TASK / DECISIONS / LESSONS 動態寫入,防偏移 ----------
// 腳本本身無檔案系統存取權,由廉價紀錄員 agent 代行;內容由 JS 組好,紀錄員只負責寫
const slug = task.toLowerCase().replace(/[^a-z0-9一-鿿]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'task'
const RUN_DIR = `.fable/runs/${slug}`

async function scribe(instruction, label) {
  const s = await agent(
    `你是紀錄員,只做指定的檔案建立/更新/append,不修改任何其他檔案、不發表意見、不改寫既有內容(TASK.md 的狀態更新除外)。每筆紀錄附上實際當下時間戳(自行取得)。寫入後確認檔案內容再回報。\n${instruction}`,
    { model: 'haiku', effort: 'low', phase: 'Log', schema: SCRIBE_RESULT, label: label || 'scribe' })
  if (!s || !s.written) {
    log(`⚠ 落盤失敗(${label || 'scribe'}):${(s && s.error) || '紀錄員未回應'} —— .fable/ 留痕不完整,收尾時需人工確認`)
  }
  return s
}

// ---------- Phase 0:理解(判斷密度最高 → opus + high effort) ----------
phase('Understand')
const u = await agent(
  `任務:${task}${extra}\n\n` +
  `你的角色是 決策核心,不是接單的工程師。使用者陳述的目標是假設,不是規格:\n` +
  `- 先想這個任務在服務什麼更上層目標(higher_goal);若提法本身限制了更好的解,在 framing_critique 提出重述。\n` +
  `- 存在真實分岔(不同價值軸指向不同最優解)時,給 2-3 個方案各標取捨並明確推薦;確實只有單一合理路徑時,第二案放你否決的次佳方案並說明否決理由(schema 固定收 2-3 案,這是單一路徑的合規形式)。\n` +
  `- 可逆的決策自己定(decision_gate=proceed)。不可逆/戰略性分歧才 user_should_choose——但**先找 reversible_default**:若存在可逆且立即可交付的預設路徑(例:先做不改語意的修復,把不可逆爭議另案上報),填入該欄位;絕不讓可交付的工作卡在待決上(交付優先)。\n` +
  `- 如果你認為這個任務問錯了問題,你的第一責任是在 framing_critique 說出來,而不是回答錯的問題。\n\n` +
  `動工前若存在 .fable/LESSONS.md 與 .fable/DECISIONS.md,先讀:避免重蹈已記錄的教訓、避免違反或重新翻案既有決策(要翻案必須在 framing_critique 明說)。\n` +
  `先實際讀相關程式碼,再輸出結構化理解。此階段禁止修改任何檔案。\n` +
  `assumptions 中,凡是能靠讀 code 或跑指令驗證的,現在就去驗證並回填 verified 與 how_verified。\n` +
  `只有「不問使用者就無法安全動工」的問題才放進 blocking_questions,其餘自行做出合理決定並記在 interpretations。\n\n` +
  `另外三個判斷:\n` +
  `- complexity:trivial(單點小修)/ standard / complex(跨模組、高不確定性)—— 這決定後續投入多少規劃冗餘。\n` +
  `- notes_for_executors:把你讀 code 時「說得出口的直覺」寫下來(哪裡聞起來有隱藏耦合、哪個檔案的慣例特殊、什麼絕對不要碰),執行者拿不到你的 context,只拿得到這段筆記。\n` +
  `- process_mismatch:僅當任務根本不適合「理解→計畫→執行→審查」流程時填原因(例如純研究問題、線上事故需要即時止血),適合則填「無」。`,
  { model: 'opus', effort: 'high', schema: UNDERSTANDING, label: 'understand' })
if (!u) throw new Error('理解階段失敗')

// 有阻塞性問題就直接把問題帶回給使用者,而不是猜 —— 這是 Fable 級行為的硬編碼
if (u.blocking_questions.length > 0) {
  await scribe(
    `建立(或覆寫)${RUN_DIR}/TASK.md:狀態=needs_user_input;任務「${task}」;阻塞問題:${JSON.stringify(u.blocking_questions)};目前理解:${u.restatement}。`,
    'log:blocked-questions')
  return { status: 'needs_user_input', questions: u.blocking_questions, understanding: u }
}

// 後設認知安全閥:流程不合身時顯式上報,而不是硬套五階段 —— 走的是和 decision_gate 同一條顯式路,不是靜默繞過
if (u.process_mismatch && u.process_mismatch !== '無') {
  await scribe(
    `append 到 .fable/DECISIONS.md:任務「${task}」判定不適合 fable-emu 流程,已上報。原因與建議:${u.process_mismatch}`,
    'log:mismatch')
  return {
    status: 'process_mismatch',
    reason: u.process_mismatch,
    understanding: u,
    how_to_resume: '同意改走建議路線就直接處理;仍要走本流程則重跑並在 context 註明「維持 fable-emu 流程」',
  }
}

// 決策核心 上報權:戰略性/不可逆的方案分歧,整理選項與推薦後直接 return,不擅自替使用者決定
const chosenName = (args && args.chosenOption) || null
// chosenOption 必須對得上本輪選項,打錯字不能被靜默當成「使用者已決定」
if (chosenName && !u.options.some(o => o.name === chosenName)) {
  return {
    status: 'needs_user_decision',
    reason: `chosenOption「${chosenName}」不在本輪選項中`,
    valid_option_names: u.options.map(o => o.name),
    options: u.options,
    recommended: { option: u.recommended_option, reason: u.recommendation_reason || '' },
    how_to_resume: '以正確的方案名重跑:args 加 {chosenOption: "<方案名>"}',
  }
}
// 交付優先:不可逆分歧存在可逆預設路徑時,不擋單 —— 先交付,爭議隨最終回報上報
let deferredDecision = null
if (!chosenName && u.decision_gate === 'user_should_choose' && u.reversible_default && u.reversible_default.trim()) {
  log(`交付優先:採可逆預設路徑「${u.reversible_default}」,不可逆爭議隨最終回報上報`)
  await scribe(
    `append 到 .fable/DECISIONS.md:任務「${task}」存在不可逆分歧,採「交付優先」—— 先執行可逆預設路徑(${u.reversible_default}),分歧留待使用者裁決,詳見任務最終回報。候選:${JSON.stringify(u.options.map(o => o.name))}。`,
    'log:deliver-first')
  deferredDecision = { question: u.framing_critique || '方案分歧', options: u.options, recommended: u.recommended_option }
  u.decision_gate = 'proceed'
}

if (!chosenName && u.decision_gate === 'user_should_choose') {
  await scribe(
    `append 到 .fable/DECISIONS.md:任務「${task}」的方案分歧屬戰略性且無可逆預設路徑,已上報使用者待決。選項:${JSON.stringify(u.options)};決策核心 推薦:${u.recommended_option}(${u.recommendation_reason || ''})。`,
    'log:escalation')
  return {
    status: 'needs_user_decision',
    higher_goal: u.higher_goal,
    framing_critique: u.framing_critique || '無',
    options: u.options,
    recommended: { option: u.recommended_option, reason: u.recommendation_reason || '' },
    how_to_resume: '選定後重跑,args 加 {chosenOption: "<方案名>"}',
  }
}
const chosen = chosenName || u.recommended_option
log(`採用方案:${chosen};完成定義:${u.definition_of_done.join(' / ')}`)
await scribe(
  `1. 建立(或覆寫)${RUN_DIR}/TASK.md:任務狀態檔。內容:任務「${task}」、狀態=planning、完成定義:${JSON.stringify(u.definition_of_done)}、採用方案「${chosen}」、上層目標:${u.higher_goal}。\n` +
  `2. append 到 .fable/DECISIONS.md:方案決策 —— 候選:${JSON.stringify(u.options.map(o => ({ name: o.name, optimizes_for: o.optimizes_for, tradeoffs: o.tradeoffs })))};採用:${chosen};理由:${u.recommendation_reason || ''};提法批評:${u.framing_critique || '無'}${chosenName ? '(由使用者選定)' : '(決策核心 自決,decision_gate=proceed)'}。`,
  'log:decision')

// ---------- Phase 1:計畫競技場(天花板機制:複雜度決定生成冗餘,漏斗不變) ----------
phase('Plan')
const planPrompt =
  `基於以下已驗證的理解,依「採用方案:${chosen}」產出分步實作計畫(方案細節見 options)。\n` +
  `每步必須小到可以獨立驗證,寫明驗證方式,並標 risk_level(high:涉及不變量/跨模組/可能破壞資料)。\n` +
  JSON.stringify(u)

// 立場配置:競技場只留給 complex;standard 單規劃者 —— 費用信封:全程 ≤ 裸 Fable 同任務成本
const STANCES = { complex: ['風險優先:先堵最可能炸的', '長期品質優先:寧慢勿髒'], standard: [], trivial: [] }
const stances = explorationOK() ? (STANCES[u.complexity] || []) : []

let plan
if (stances.length >= 2) {
  const candidates = (await parallel(stances.map((s, i) => () =>
    agent(`${planPrompt}\n\n你的規劃立場:${s}。堅持這個立場出案,不要折衷。`,
      { model: 'opus', effort: 'high', schema: PLAN, phase: 'Plan', label: `plan-c${i}` })
  ))).filter(Boolean)
  if (candidates.length >= 2) {
    // 裁判合成:採勝者骨架、嫁接敗者好想法 —— 合成的計畫仍走同一套執行+驗證,沒有 VIP 通道
    plan = await agent(
      `你是計畫裁判。以下是 ${candidates.length} 份不同立場的候選計畫(對應立場:${JSON.stringify(stances)}):\n` +
      JSON.stringify(candidates) + `\n\n` +
      `評估各案的骨架與亮點,輸出「合成後的最終計畫」:以最強的骨架為底,嫁接其他案值得保留的步驟或防護,並在 judge_rationale 說明取捨。\n任務理解:${JSON.stringify(u)}`,
      { model: 'opus', effort: 'high', schema: PLAN, phase: 'Plan', label: 'plan-judge' })
    if (plan) log(`競技場:${candidates.length} 案合成;${plan.judge_rationale || ''}`)
  }
  if (!plan) plan = candidates[0] || null
}
if (!plan) {
  plan = await agent(planPrompt, { model: 'opus', effort: 'high', schema: PLAN, label: 'plan' })
}
if (!plan || !plan.steps.length) throw new Error('計畫階段失敗')

// 洞察代理(只留給 complex —— 它是成本大戶,standard 任務的計畫不需要 xhigh 顧問)
let advisoryNotes = ''
if (u.complexity === 'complex' && explorationOK()) {
  const insight = await agent(
    `你是洞察者。一個比這份計畫的作者更強的工程師,會看到什麼這份計畫沒看到的東西?\n` +
    `找:隱藏耦合、更根本的解法、三層間接之外的風險、計畫假設與 code 現實的落差。實際讀 code 求證,不要泛泛而談。\n` +
    `計畫:${JSON.stringify(plan)}\n任務理解:${JSON.stringify(u)}`,
    { model: 'opus', effort: 'high', schema: INSIGHT, phase: 'Plan', label: 'insight' })
  if (insight && insight.plan_verdict === 'needs_revision') {
    const fundamental = insight.insights.filter(i => i.severity === 'fundamental')
    log(`洞察代理判定計畫需修訂:${fundamental.map(i => i.observation).join(';')}`)
    const revised = await agent(
      `依洞察者的發現修訂計畫(只處理 fundamental 與 notable 級的發現,不要推翻整體方向):\n` +
      `發現:${JSON.stringify(insight.insights)}\n原計畫:${JSON.stringify(plan)}\n任務理解:${JSON.stringify(u)}`,
      { model: 'opus', effort: 'high', schema: PLAN, phase: 'Plan', label: 'plan-revised' })
    if (revised && revised.steps.length) plan = revised
    await scribe(`append 到 .fable/DECISIONS.md:洞察代理修訂計畫 —— ${JSON.stringify(insight.insights)}`, 'log:insight')
  } else if (insight && insight.insights.length) {
    advisoryNotes = insight.insights.map(i => `[${i.severity}] ${i.observation}${i.suggestion ? '(建議:' + i.suggestion + ')' : ''}`).join('\n')
  }
}

// 異端沙箱(opt-in,天花板機制):隔離 worktree 裡試一條根本不同的路線;唯讀主線、絕不自動合流
let maverickP = null
if (args && args.maverick && explorationOK()) {
  log('異端沙箱啟動:平行嘗試一條與主計畫根本不同的路線(隔離 worktree,不影響主線)')
  maverickP = agent(
    `你是異端工程師,在隔離的工作區裡工作(你的變更不會影響主線)。\n` +
    `任務:${task}\n主線採用的方案與計畫:${JSON.stringify({ chosen, plan })}\n` +
    `你的工作:選一條與主計畫「根本不同」的路線解決同一任務,實作並驗證。\n` +
    `最後回報:你的路線、實測結果(附輸出)、與主計畫路線的優劣對比、你會不會建議改用你的路線。`,
    { model: 'opus', effort: 'high', isolation: 'worktree', phase: 'Plan', label: 'maverick' }
  ).catch(() => null)
}

log(`計畫 ${plan.steps.length} 步,最高風險在步驟 ${plan.riskiest_step}`)
await scribe(
  `更新 ${RUN_DIR}/TASK.md:狀態改為 executing,加入計畫步驟清單(checkbox,全部未勾):\n` +
  plan.steps.map(s => `- [ ] 步驟${s.id}:${s.action}(驗證:${s.verification};風險:${s.risk_level})`).join('\n') +
  (plan.judge_rationale ? `\n並 append 到 .fable/DECISIONS.md:計畫競技場合成理由 —— ${plan.judge_rationale}` : ''),
  'log:plan')

// ---------- Phase 2:逐步執行 + 風險分級驗證(步驟相依 → 循序,不能平行) ----------
const journal = []
const queue = plan.steps.slice()
let replans = 0
const execNotes = [u.notes_for_executors, advisoryNotes].filter(s => s && s.trim()).join('\n')

while (queue.length) {
  const step = queue.shift()
  if (budget.total && budget.remaining() < 30000) {
    log(`token 預算不足,於步驟 ${step.id} 前提前收斂`)
    await scribe(`更新 ${RUN_DIR}/TASK.md:狀態改為 budget_exhausted,停在步驟 ${step.id} 之前。已完成:${JSON.stringify(journal)}`, 'log:budget')
    return { status: 'budget_exhausted', journal, plan }
  }

  let verified = false
  let result = null
  let critique = ''
  let invalidated = false
  for (let attempt = 0; attempt <= MAX_REPAIR; attempt++) {
    const escalate = attempt === MAX_REPAIR // 最後一次機會升級到 opus 修
    result = await agent(
      `執行計畫步驟 ${step.id}:${step.action}\n` +
      `涉及檔案:${(step.files || []).join(', ') || '(依實況判斷)'}\n` +
      `已完成的前置步驟:${JSON.stringify(journal)}\n` +
      (execNotes ? `理解者與洞察者的現場筆記(直覺與警告,認真對待):\n${execNotes}\n` : '') +
      (critique ? `上次嘗試被驗證者駁回,理由:${critique}\n請針對駁回理由修正後重做。\n` : '') +
      `完成後必須實際執行驗證:${step.verification},把真實輸出貼進 verification_output。\n` +
      `遇到計畫外狀況不要硬掰:這一步做不到 → status=blocked 並在 deviation 說明;` +
      `發現整份計畫的前提被現實推翻 → plan_invalidated=true 並在 invalidation_reason 說明是哪個前提、被什麼事實推翻。`,
      { model: escalate ? 'opus' : 'sonnet', phase: 'Execute', schema: STEP_RESULT, label: `step${step.id}.try${attempt}` })

    if (!result) break
    // 重規劃回路:計畫前提失效 ≠ 這一步失敗,跳出交給重規劃處理
    if (result.plan_invalidated) { invalidated = true; break }
    // blocked 不直接放棄:把障礙回饋給下一次嘗試(最後一次會升級 Opus),真的無解才會在迴圈耗盡後回報
    if (result.status === 'blocked') {
      critique = `執行者回報 blocked:${result.deviation || result.summary}。若此障礙可換作法解決,請換方法完成;若確實無法推進,再次回報 blocked 並說明原因。`
      continue
    }

    // 風險分級驗證:分級只降「生成成本」,不降「阻斷力」—— low 用低 effort 單驗證者,high 用雙鏡頭且全過才放行
    const verifyBase =
      `對抗式驗證。假設步驟 ${step.id} 的修改是錯的,實際讀變更內容、重跑驗證,盡力找出它壞掉的方式。\n` +
      `步驟目標:${step.action}\n驗證方式:${step.verification}\n執行者回報:${JSON.stringify(result)}`
    if (step.risk_level === 'high') {
      const lenses = ['正確性鏡頭:重跑驗證、逐行讀 diff', '回歸鏡頭:找出這個修改弄壞「其他既有行為」的方式']
      const vs = await parallel(lenses.map((l, li) => () =>
        agent(`${verifyBase}\n你的驗證視角:${l}`,
          { model: 'sonnet', phase: 'Execute', schema: VERDICT, label: `verify${step.id}.try${attempt}.lens${li}` })))
      const refuter = vs.filter(Boolean).find(v => v.refuted)
      if (!vs.some(v => !v) && !refuter) { verified = true; break }
      critique = refuter ? refuter.reason : '有驗證者未回應,證據不足不得放行'
    } else {
      // low 風險用 haiku 驗證 —— 降的是生成成本,refuted 照樣硬擋
      const v = await agent(verifyBase,
        { model: 'haiku', effort: 'low', phase: 'Execute', schema: VERDICT, label: `verify${step.id}.try${attempt}` })
      if (v && !v.refuted) { verified = true; break }
      critique = v ? v.reason : '驗證者未回應'
    }
  }

  // 重規劃回路(有界:一次):帶著已完成的事實回到規劃,替換剩餘步驟 —— 「連續流轉向」的離散化近似
  if (invalidated) {
    journal.push({ step: step.id, action: step.action, passed: false, summary: `計畫前提失效:${result.invalidation_reason || result.summary}` })
    if (replans >= 1) {
      await scribe(`更新 ${RUN_DIR}/TASK.md:狀態改為 blocked —— 計畫前提二度失效:${result.invalidation_reason || ''}`, 'log:blocked')
      return { status: 'blocked', at_step: step.id, journal, reason: `計畫前提二度失效,不再重規劃:${result.invalidation_reason || ''}` }
    }
    replans++
    log(`計畫前提失效,重規劃剩餘工作(僅此一次):${result.invalidation_reason || ''}`)
    await scribe(`append 到 .fable/DECISIONS.md:任務「${task}」於步驟 ${step.id} 觸發重規劃 —— 失效前提:${result.invalidation_reason || result.summary}。`, 'log:replan')
    const rp = await agent(
      `原計畫的前提已被現實推翻:${result.invalidation_reason || result.summary}\n` +
      `已完成的步驟(既成事實,不可假裝沒發生;必要時排回退步驟):${JSON.stringify(journal)}\n` +
      `原計畫:${JSON.stringify(plan)}\n任務理解:${JSON.stringify(u)}\n` +
      `基於現實重新規劃「剩餘」的工作,每步含驗證方式與 risk_level。`,
      { model: 'opus', effort: 'high', schema: PLAN, phase: 'Plan', label: 'replan' })
    if (!rp || !rp.steps.length) {
      return { status: 'blocked', at_step: step.id, journal, reason: '重規劃失敗' }
    }
    queue.length = 0
    queue.push(...rp.steps)
    await scribe(
      `更新 ${RUN_DIR}/TASK.md:重規劃生效,新的剩餘步驟清單:\n` +
      rp.steps.map(s => `- [ ] 步驟${s.id}:${s.action}(驗證:${s.verification};風險:${s.risk_level})`).join('\n'),
      'log:replan-plan')
    continue
  }

  journal.push({ step: step.id, action: step.action, passed: verified, summary: result ? result.summary : '(無結果)' })

  // 成功步驟的落盤收尾批次處理(見迴圈後);失敗/曾駁回的即時落盤(罕見路徑,可觀測性優先)
  if (critique) {
    await scribe(
      `1. 更新 ${RUN_DIR}/TASK.md:步驟 ${step.id} 標記為 ${verified ? '[x] 完成(曾被駁回後修正)' : '[!] 失敗'}。\n` +
      `2. append 到 .fable/LESSONS.md:任務「${task}」步驟 ${step.id}(${step.action})曾被對抗驗證駁回,理由:${critique}。${verified ? '最終已修正通過。' : '至此仍未通過。'}`,
      `log:step${step.id}`)
  }

  if (!verified) {
    await scribe(`更新 ${RUN_DIR}/TASK.md:狀態改為 blocked(卡在步驟 ${step.id});原因:${critique || (result && result.deviation) || '執行失敗'}`, 'log:blocked')
    return {
      status: 'blocked', at_step: step.id, journal,
      reason: critique || (result && result.deviation) || (result && result.summary) || '執行失敗',
    }
  }
}

// 成功步驟批次落盤 + 交付檢查點(隨做隨寫:此後即使被截斷,交付物已在磁碟上,只缺審查背書)
await scribe(
  `更新 ${RUN_DIR}/TASK.md:以下步驟勾選完成 —— ${journal.filter(j => j.passed).map(j => `步驟${j.step}(${j.summary})`).join(';')}。狀態改為 reviewing。\n` +
  `並 append 一節「## 交付檢查點(執行完成,${journal.filter(j => j.passed).length} 步)」:逐步驟摘要與驗證結果 ${JSON.stringify(journal)}——若後續階段中斷,交付物以此為準,狀態視為「已交付未審查」。`,
  'log:steps-batch')

// ---------- Phase 3:跨模型對抗審查(不同家族的盲點不重疊) ----------
phase('CrossReview')
const reviewPrompt =
  `審查目前工作區的所有未提交變更。你的立場是反方:預設這份修改有錯,盡力反駁。\n` +
  `任務目標:${task}\n完成定義:${u.definition_of_done.join(' / ')}\n` +
  `只回報有實質影響的問題,風格瑣事標 minor。`

async function tryReview(agentType, label) {
  try {
    return await agent(reviewPrompt, { agentType, schema: REVIEW, phase: 'CrossReview', label })
  } catch (e) {
    log(`${label} 不可用,略過:${e.message}`)
    return null
  }
}

// 預設單一跨模型審查者(取第一個可用);args.thorough 才雙評
let reviews = []
if (args && args.thorough) {
  reviews = (await parallel([
    () => tryReview('codex:codex-rescue', 'review:codex'),
    () => tryReview('agy-bridge', 'review:agy'),
  ])).filter(Boolean)
} else {
  const r1 = await tryReview('codex:codex-rescue', 'review:codex')
  if (r1) { reviews = [r1] } else {
    const r2 = await tryReview('agy-bridge', 'review:agy')
    if (r2) reviews = [r2]
  }
}

// 跨模型 CLI 都不在時,退回同家族「人格審查團」:用資訊不對稱與證據通道差異買回獨立性
// (規格律師不看實作理由、回歸獵人不看任務目的)。權重相同的共享盲點補不回——
// 靠後段仲裁強制讀 code 攔截,並在留痕與最終回報明示降級成色
let reviewMode = 'cross-model'
if (!reviews.length) {
  reviewMode = 'same-family-panel'
  log(`Codex/Agy 均不可用,降級為同家族人格審查團(規格律師 + 回歸獵人${args && args.thorough ? ' + 不變量稽核' : ''});無跨家族盲點覆蓋`)
  const panel = [
    () => agent(
      `你是規格律師。先不看任何實作:根據下列任務語句與完成定義,獨立推導「正確的實作應該具備哪些可觀察行為」,列成清單;然後才審查目前工作區的所有未提交變更,逐條對照你的清單。\n` +
      `你的立場是反方:預設實作偏離了規格,盡力找出「做了但不是要的」與「要的但沒做」。\n` +
      `每個發現必須附 file:line 或指令輸出佐證,無佐證的猜測不得列入。只回報有實質影響的問題,風格瑣事標 minor。\n` +
      `任務:${task}\n完成定義:${u.definition_of_done.join(' / ')}`,
      { model: 'sonnet', schema: REVIEW, phase: 'CrossReview', label: 'review:spec-lawyer' }),
    () => agent(
      `你是回歸獵人。審查目前工作區的所有未提交變更。刻意不告訴你這次修改的目的——你的工作不是評價改得有沒有道理,而是找出它弄壞了什麼既有行為:\n` +
      `(1) 對 diff 中每個被修改的函式/符號,grep 其所有呼叫點逐一檢查相容性;(2) 實際跑既有測試並讀完整輸出。\n` +
      `每個發現必須附 file:line 或指令輸出佐證,無佐證的猜測不得列入。只回報有實質影響的問題,風格瑣事標 minor。`,
      { model: 'sonnet', schema: REVIEW, phase: 'CrossReview', label: 'review:regression-hunter' }),
  ]
  if (args && args.thorough) {
    panel.push(() => agent(
      `你是不變量稽核。讀 docs/invariants.md 與 CONTEXT.md 的「已知地雷」(若存在),對目前工作區的所有未提交變更逐條核對:有沒有任何一條不變量被這次修改觸碰或削弱?\n` +
      `每個發現必須附 file:line 佐證並指明違反哪一條。檔案不存在或全部通過 → approved=true、findings 空陣列。`,
      { model: 'opus', schema: REVIEW, phase: 'CrossReview', label: 'review:invariant-auditor' }))
  }
  reviews = (await parallel(panel)).filter(Boolean)
}

// 零審查不得靜默前進:未經任何審查的變更不能走到「完成」
if (!reviews.length) {
  await scribe(`更新 ${RUN_DIR}/TASK.md:狀態改為 review_unavailable —— 跨模型與人格審查團備援全部失敗,變更已實作但未經任何審查。`, 'log:review-unavailable')
  return { status: 'review_unavailable', journal, reason: '所有審查者(Codex/Agy/人格審查團備援)均無有效回應;變更未經審查,不得視為完成' }
}

// 聚合與去重是純 JS —— 模型無權決定「哪些發現可以不管」
const rawFindings = reviews.flatMap(r => r.findings).filter(f => f.severity !== 'minor')
const seen = new Set()
const findings = rawFindings.filter(f => {
  const key = `${f.file || ''}::${f.summary}`
  if (seen.has(key)) return false
  seen.add(key)
  return true
})
log(`審查發現 ${findings.length} 個非 minor 問題(去重後)`)

// 每個發現交 Opus 仲裁,確認為真的才進入修復
const fixedFindings = []
if (findings.length) {
  const verdicts = await parallel(findings.map(f => () =>
    agent(
      `仲裁以下審查發現是否為真問題。實際讀 code 求證,不接受審查者的臆測,也不因為是外部模型提的就照單全收。\n` +
      JSON.stringify(f),
      { model: 'opus', effort: 'high', schema: ARBITRATION, phase: 'CrossReview', label: `arbitrate:${(f.file || 'general').slice(-30)}` })))

  for (let i = 0; i < findings.length; i++) {
    if (!verdicts[i] || !verdicts[i].is_real) continue
    const f = findings[i]
    const fix = await agent(
      `修復已確認的審查問題:${f.summary}(檔案:${f.file || '未指明'})\n仲裁意見:${verdicts[i].reason}\n` +
      `修完後重跑相關驗證,貼真實輸出。`,
      { model: 'sonnet', phase: 'CrossReview', schema: STEP_RESULT, label: `fix:${(f.file || 'general').slice(-30)}` })
    const recheck = await agent(
      `對抗式驗證此修復是否真的解決了問題且未引入新問題:${JSON.stringify({ finding: f, fix })}`,
      { model: 'opus', phase: 'CrossReview', schema: VERDICT, label: `refix-verify` })
    fixedFindings.push({ finding: f.summary, fixed: !!(recheck && !recheck.refuted) })
  }

  await scribe(
    `1. append 到 .fable/DECISIONS.md:跨模型審查仲裁 —— ${JSON.stringify(findings.map((f, i) => ({ finding: f.summary, is_real: !!(verdicts[i] && verdicts[i].is_real), reason: verdicts[i] ? verdicts[i].reason : '仲裁未回應' })))}(駁回的發現與理由也要留痕,避免未來重複提報)。\n` +
    (fixedFindings.length
      ? `2. append 到 .fable/LESSONS.md:任務「${task}」中執行層沒抓到、由跨模型審查抓到的盲點:${JSON.stringify(fixedFindings)}。`
      : ''),
    'log:review')
}

// 已確認的審查問題修復失敗 = 硬阻斷,不得流進「完成」——這裡是最需要保守的地方
const unfixed = fixedFindings.filter(f => !f.fixed)
if (unfixed.length) {
  await scribe(`更新 ${RUN_DIR}/TASK.md:狀態改為 blocked_on_review —— 已確認的審查問題修復失敗:${JSON.stringify(unfixed)}。`, 'log:review-blocked')
  return {
    status: 'blocked_on_review', journal, unfixed_findings: unfixed,
    reason: '跨模型審查確認為真的問題修復失敗,不得宣稱完成',
  }
}

// 審查通過檢查點(隨做隨寫:審查背書落盤,之後的完整性/檢討被截斷也不影響交付)
await scribe(
  `更新 ${RUN_DIR}/TASK.md:狀態改為 reviewed;append「## 交付檢查點(審查完成)」—— 審查者 ${reviews.length} 位(模式:${reviewMode}${reviewMode === 'same-family-panel' ? ',同家族人格團降級,無跨家族盲點覆蓋' : ''}),確認並修復的問題:${JSON.stringify(fixedFindings)}(空陣列 = 無確認問題)。`,
  'log:review-done')

// ---------- Phase 4:完整性批評(對照凍結清單 + 重推導活的期望) ----------
phase('Completeness')

// 異端沙箱回收:報告僅供參考與留痕,絕不自動合流 —— 想採納它的路線是使用者層級的決策
let maverickReport = null
if (maverickP) {
  maverickReport = await maverickP
  if (maverickReport) {
    await scribe(`append 到 .fable/DECISIONS.md:異端沙箱報告(未合流,僅供比較)—— ${JSON.stringify(maverickReport).slice(0, 2000)}`, 'log:maverick')
  } else {
    log('異端沙箱未產出有效報告(可能非 git repo 或 agent 失敗)')
  }
}

const gapReport = await agent(
  `完整性批評,三重檢查:\n` +
  `1. 對照完成定義逐項核對(未做的項目、沒驗證的宣稱、沒處理的邊界)。\n` +
  `2. 重讀原始任務語句與上層目標,重新推導期望 —— 完成定義本身可能寫漏了,清單之外的也要看。\n` +
  `3. 關鍵問句:使用者拿到成果後,發現什麼「沒做」會感到驚訝?\n` +
  `全部達成則回空陣列。\n` +
  `原始任務:${task}\n上層目標:${u.higher_goal}\n完成定義:${JSON.stringify(u.definition_of_done)}\n` +
  `工作紀錄:${JSON.stringify(journal)}\n審查修復:${JSON.stringify(fixedFindings)}`,
  { model: 'opus', effort: 'high', schema: GAPS, label: 'completeness' })

const gaps = gapReport ? gapReport.gaps : ['完整性批評者未回應']

// ---------- Phase 5:賽後檢討(只在有事可檢討時跑;平順的 run 不燒檢討費) ----------
phase('Retro')
let retro = null
if (replans > 0 || fixedFindings.length > 0 || gaps.length > 0) {
retro = await agent(
  `你是流程檢討者。讀 .fable/LESSONS.md(若存在),對照本次工作紀錄,回答:\n` +
  `1. 本次哪個環節浪費了?(多餘的驗證、重複同樣理由的無效重試、prompt 誤導執行者)\n` +
  `2. 對 workflow 本身有什麼具體修改建議?\n` +
  `3. LESSONS 裡有沒有重複出現、值得升格為 CLAUDE.md 條款或 invariants 的教訓?\n` +
  `沒有就回空陣列,不要為了交差硬湊。\n` +
  `本次紀錄:${JSON.stringify({ journal, fixedFindings, gaps, replans })}`,
  { model: 'sonnet', effort: 'low', schema: RETRO, label: 'retro' })
if (retro && (retro.process_waste.length || retro.kit_suggestions.length || retro.candidate_rules.length)) {
  await scribe(
    `append 到 .fable/KIT-SUGGESTIONS.md,**每條建議獨立一行**,嚴格使用此格式(hook 依此機械計數):\n` +
    `- [pending] <一句話建議>(證據:任務「${task}」;<今日日期>)\n` +
    `內容來源:${JSON.stringify(retro)}。\n` +
    `檔案開頭若無說明,先寫一行:「# KIT-SUGGESTIONS(人審後把 [pending] 改為 [accepted]/[rejected];僅 accepted 可入法 CLAUDE.md/invariants/DECISION-CORE)」。`,
    'log:retro')
}
}

await scribe(
  `更新 ${RUN_DIR}/TASK.md:狀態改為 ${gaps.length ? 'done_with_gaps' : 'done'}。` +
  (gaps.length ? `未完成項(remaining gaps):${JSON.stringify(gaps)}。` : '全部完成定義已達成。'),
  'log:final')
return {
  status: gaps.length ? 'done_with_gaps' : 'done',
  definition_of_done: u.definition_of_done,
  journal,
  replans,
  cross_review: {
    reviewers: reviews.length,
    mode: reviewMode,
    degradation_note: reviewMode === 'same-family-panel' ? '跨模型 CLI 不可用,本次審查為同家族人格團(資訊不對稱設計),無跨家族盲點覆蓋' : null,
    findings_confirmed_and_fixed: fixedFindings,
  },
  remaining_gaps: gaps,
  maverick: maverickReport ? { report: maverickReport, note: '未合流;要採納異端路線請明確指示' } : null,
  retro: retro || null,
  deferred_decision: deferredDecision ? Object.assign(deferredDecision, { note: '交付優先:可逆部分已完成,此不可逆分歧待你裁決' }) : null,
}
