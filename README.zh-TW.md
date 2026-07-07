# fable-harness-kit

[English](README.md) | **繁體中文**

**給 Claude Code 使用者的多模型開發 Harness 模板**:不換更貴的模型,用流程強制力買回思考維度。
把「哪裡該懷疑、懷疑幾次、誰仲裁、何時收斂」從模型天性下沉為 hooks 與 workflow 腳本,
讓 **Opus 4.8(規劃/仲裁)+ Sonnet(執行)+ Codex/Agy(跨模型審查)** 逼近 Fable 級輸出——
成本信封:≤ 裸 Fable 5 做同一件事。

核心等式:**Opus 4.8 + fable-emu workflow(編排判斷的預編譯)≈ Fable 5**

**證據等級聲明**:上述等式與成本信封來自作者的內部消融實驗(4 組 × 3 run、雙盲評分,2026-07),
原始數據未隨 kit 公開——採用者應將其視為**工作假設**,在自己的任務上驗證,而非已確立的 benchmark。
本套件自己的決策核心也是這樣要求的:未驗證的宣稱是待驗假設,不是真理。
**2026-07-07 更新**:首次對照測量(`benchmark/REPORT.md`,預註冊協議、非 Claude 家族雙裁判盲評)
在 4 個小-中型可驗證任務上支持等式:通過率 4/4 平手、品質差 −0.13(容忍 −0.5)、成本 59%。
證據等級:**校準級(n=4)**,不外推到大型長程任務(見報告的誠實解讀節)。
原始佐證(裁判 prompt/回覆全文、揭盲映射、兩臂結果)公開於 [`benchmark/evidence/`](benchmark/evidence/)。
**消融追補(同日,裸 Opus 臂 12/12)**:在此難度帶裸 Opus 已飽和且最便宜——kit 的增量
**不是簡單任務的通過率**(那裡 kit 稅約 +$0.12/run,買的是防護與審計留痕),性能增量
待更難任務帶(v2)證明或證偽。誠實的定位:kit 是**紀律、防護與審計層**,不是加速器。

> **給誰用**:主力模型是 Opus/Sonnet、想要 Fable 級的自我懷疑與驗證紀律、且在意成本的團隊。
> **前置需求**:Claude Code(Windows;hooks 與腳本為 PowerShell,mac/linux 需自行 port 或改用 pwsh)。
> 選配:codex plugin 與 agy CLI(跨模型審查;缺席時自動降級為單模型審查並留痕)。
> **非 Claude Code 使用者**:hooks 與 workflow 強制力**不可移植**;可移植的是提詞條款與決策核心
> (Codex 側放 AGENTS.md、Gemini 側放 GEMINI.md),見 `docs/HARNESS.md` §2.5。
> **快速開始**:GitHub 上點「Use this template」建新專案,或對既有 repo 跑 `init.ps1`(見下)。

## 套件內容

```
fable-harness-kit/
├── README.md / README.zh-TW.md     # 本檔(英/中,不會被複製到目標 repo)
├── init.ps1                         # 一鍵初始化腳本(不會被複製)
├── CLAUDE.md                        # 模板:分級路由 + 決策核心 + 提詞限制條款(需填 TODO)
├── CONTEXT.md                       # 模板:領域語言字典 + 架構地圖(需填)
├── fable-run.ps1                    # headless Tier 2/3 監督式執行器(截斷偵測 + resumeFromRunId 續跑)
├── docs/
│   ├── DECISION-CORE.md             # 決策核心:授權 / 資訊裁決 / 判準,含正反例與實證標記
│   ├── TIER3-FRONTIER.md            # 前沿模式:深潛提詞模板(去指令化)+ 競試用法與成本數學
│   ├── HARNESS.md                   # 完整設計指南(提詞天花板對照表、模型路由)
│   ├── invariants.md                # 模板:不變量清單(弱模型的護欄)
│   └── adr/
│       └── 0001-adopt-fable-harness.md  # ADR 格式範例(兼記錄本套件的採用)
├── benchmark/                       # 對照基準:裸 Fable 5 vs kit 化 Opus(PROTOCOL.md 預註冊;
│                                    #   run-benchmark.ps1 收驗收/成本/時間,judge.ps1 非 Claude 家族雙裁判盲評)
├── scripts/
│   ├── canary.ps1                   # 金絲雀:fable-emu 修改後一鍵端到端實跑(固定 fixture + artifact)
│   ├── schedule-canary.ps1          # 每週排程金絲雀:感測上游模型暗改(靜態測試唯一攔不到的盲區)
│   └── upstream-suggestions.ps1     # 艦隊回流:各部署專案的 [accepted] 建議回流 kit repo 成 issue
├── tests/                           # 行為契約:hooks(Pester)+ workflow(node --test,stub 執行器)+ 人格同步
└── .claude/
    ├── settings.json                # hooks 配置(六支,含兩支 Stop gate:verify 在前、retro 在後)
    ├── status-contract.json         # workflow 狀態契約單源(fable-run 執行期載入;fable-emu 測試期對帳)
    ├── agents/
    │   ├── spec-lawyer.md           # 反方:規格律師(先推導期望行為再對照 diff;不吃作者辯詞)
    │   ├── regression-hunter.md     # 反方:回歸獵人(只看 diff+一句話目的;義務 grep 呼叫點+跑測試)
    │   └── invariant-auditor.md     # 反方:不變量稽核(逐條核對 invariants + 範圍紀律)
    ├── hooks/
    │   ├── git-guard.ps1            # PreToolUse:攔危險指令
    │   ├── session-brief.ps1        # SessionStart:鐵律 + LESSONS/DECISIONS + 待審建議計數 + 蒸餾觸發
    │   ├── prompt-nudge.ps1         # UserPromptSubmit:每回合一行輕推(建 .claude/nudge-off 可關)
    │   ├── verify-gate.ps1          # Stop①:改了程式檔卻無測試痕跡 → 擋一次,補證據或明說未驗證
    │   ├── stop-retro-gate.ps1      # Stop②:有修改的 session 收尾前強制檢討一次
    │   └── rule-guard.ps1           # PostToolUse:規則檔變更自動留痕 DECISIONS.md(血統可追溯)
    └── workflows/
        ├── fable-emu.js             # Tier 2:理解→計畫→執行→跨模型審查→完整性
        └── deep-attempts.js         # Tier 3 競試:N 個平行深潛(worktree 隔離)+ 裁判實測擇優
```

反方 agents 可在 Tier 0/1 直接點名派用(如「派 spec-lawyer 審這個 diff」),與 fable-emu 的
Tier 2 人格團同源同設計(資訊裁切:裁作者的說服,不裁判斷所需的事實)。

## 初始化方式

```powershell
# 方式一:腳本(只複製目標 repo 中不存在的檔案,絕不覆蓋)
powershell -NoProfile -ExecutionPolicy Bypass -File .\init.ps1 -Target C:\path\to\your\repo

# 方式二:手動
# 把 README.md 和 init.ps1 以外的所有內容,照原始目錄結構複製到目標 repo 根目錄
```

## 初始化(三步,不用讀手冊)

```
1. powershell -File init.ps1 -Target <你的專案>       # 鋪檔案(只增不覆蓋)
2. 在該專案開 Claude Code,輸入:/fable-setup          # Claude 引導完成剩下所有事
3. powershell -File scripts\doctor.ps1                 # 全綠 = 完成
```

`/fable-setup` 會:自動偵測 build/test/lint 指令填進 CLAUDE.md、掃 repo 起草 CONTEXT 與
invariants(只有「設計意圖/地雷」這類偵測不到的才問你,最多三問)、想要自動 lint 就由它
安全地改 settings.json(你不用碰 JSON)、最後帶你試跑一個小任務。

<details>
<summary><b>手動路徑與細節(進階,點開)</b></summary>

1. **CLAUDE.md**:填掉所有 `TODO(...)`——build/test/lint 指令、Tier 1 高風險區、規格來源。
2. **CONTEXT.md**:領域名詞表 + 架構地圖。寫「為什麼」,不寫 code 本身能看出的東西。
3. **docs/invariants.md**:絕不能破壞的規則,一條一行、可判定。
4. **跨模型審查**:`codex` 或 `agy` 任一在 PATH 即可(橋接員現場偵測直呼,echo 接地驗收,
   不需任何 plugin);兩者皆缺自動降級同家族人格審查團(裁作者的說服、不裁事實),
   降級成色會在留痕與最終回報明示。
5. **改 fable-emu.js 的紀律**:先跑契約測試
   `node --test tests/workflow-contract.test.mjs tests/persona-sync.test.mjs`(秒級),
   merge 前跑 `scripts/canary.ps1` 端到端金絲雀(~$1)——unit 保契約、金絲雀保現實。
6. **自動 lint/typecheck(選配)**:在既有 PostToolUse 陣列**追加** handler,
   勿整段替換(會蓋掉 rule-guard 留痕 hook);格式參考 `.claude/settings.json`。

</details>

## 成本信封(消融實驗定案;原始數據在開發庫 ab-test-v2,未隨 kit 搬移)

**設計目標:成本 ≤ 裸 Fable 5 同任務、時間同量級、品質不輸。**
實測依據:提詞層(Tier 0)以 ~$0.5 / 2 分鐘拿到盲評最高分。

- **分級路由**(CLAUDE.md):Tier 0 提詞層(預設)→ Tier 1 +fresh-context 驗證者(高風險單模組)→ Tier 2 fable-emu(跨模組/不可逆,僅互動式 session)。
- **fable-emu 成本控制**:競技場與洞察代理只留 complex;審查預設單評者(`args.thorough` 才雙評);low 風險步驟 haiku 驗證;成功步驟批次落盤;檢討只在有事可檢討時跑。目標成本 ~$1.0-1.3。
- **交付優先判準**:不可逆分歧若存在可逆預設路徑 → 先交付、爭議隨最終回報上報(`reversible_default`),不再為可逆工作擋單。
- **引用不複製**:任務理解落盤 `.fable/runs/<slug>/ctx.md` 供各 agent 按需讀取,執行步驟只帶
  進度一行 + 上一步詳情(舊版每步注入全部歷史,context 成本隨步數平方成長);大輸出寫檔回傳路徑。
- **成本遙測**:fable-run 每輪加總 stream-json 的 `total_cost_usd` 與 tokens,印出並 append 到
  `.fable/COST-LOG.md`——信封宣稱由每次 run 自動累積實測分布,自我審計。
- **對照基準**:`benchmark/` 以預註冊協議(PROTOCOL.md)對照裸 Fable 5 與 kit 化 Opus——
  核心等式從「工作假設」升級為「可覆核測量」的機制;利益衝突控制:非 Claude 家族雙裁判盲評。
- **headless 截斷防護**:`fable-run.ps1` 監督式執行器(TASK.md 終態偵測 +
  `--continue` resumeFromRunId 續跑,上限 2 次)+ fable-emu 階段邊界交付檢查點(截斷不丟交付物)。
- **Tier 3(前沿模式)**:難題不進編排管線(編排是中等任務的槓桿、難題的稅)——深潛用單一
  Opus xhigh session 燒到底(同錢 = Fable 兩倍 tokens);可驗證的難題用 deep-attempts 競試。
  詳見 docs/TIER3-FRONTIER.md,含誠實邊界(無驗證器的品味題與多日級長跑仍屬 Fable)。

## Context 占用(harness 的固定稅,實測估算)

| 口徑 | Tokens(約) | 佔 1M 窗口 |
|---|---|---|
| 每 session 自動載入(CLAUDE.md + hook 注入鐵律) | 2,600 | 0.26% |
| 動工一個任務(+ 必讀:DECISION-CORE / CONTEXT / invariants) | 4,300 | 0.43% |
| 全套件通讀(僅在被要求讀整個 kit 時發生) | 27,000 | 2.7% |

- `.fable/LESSONS.md`、`DECISIONS.md` 的注入尾巴會隨累積成長(封頂約再 +1,500),過長時 SessionStart hook 會提示蒸餾。
- fable-emu.js(~11k tokens)正常運作**不進主模型 context**:workflow 由 harness 執行,內部 prompt 分段發給各 subagent,各自計費。
- 估算係數:CJK 字 ≈ 1.1 token、其餘 ≈ 4 字元/token,誤差約 ±30%。

## 天花板機制(生成端加碼,驗證漏斗不變)

原則:**天花板加在生成端,地板鎖在驗證端,兩端永不互換。** 所有探索性產出想合流,一律走同一套驗證漏斗,沒有 VIP 通道。

| 機制 | 做什麼 | 觸發條件 |
|---|---|---|
| 複雜度分級 | Understand 判 trivial/standard/complex,決定後續投入多少規劃冗餘 | 每次 |
| 計畫競技場 | 2 個立場迥異的規劃者平行出案,裁判合成 | **僅 complex** + 預算足 |
| 洞察代理 | 「更強的工程師會看到什麼這份計畫沒看到的?」fundamental 級發現觸發一次計畫修訂 | **僅 complex** + 預算足 |
| 重規劃回路 | 執行中發現「計畫前提被現實推翻」→ 帶著既成事實回規劃重排剩餘步驟(限一次) | plan_invalidated |
| 風險分級驗證 | high 風險步驟雙鏡頭驗證(正確性+回歸)全過才放行;low 用 haiku 單驗證。分級只降生成成本,不降阻斷力 | 每步 |
| 後設認知安全閥 | 任務根本不適合本流程時顯式上報建議路線,不硬套五階段 | process_mismatch |
| 異端沙箱 | 隔離 worktree 平行試一條根本不同的路線,報告僅供比較,絕不自動合流 | args.maverick(opt-in) |
| 賽後檢討 | 產出流程浪費分析與「教訓升格為規則」候選,寫入 .fable/KIT-SUGGESTIONS.md 供人審 | 有事可檢討時(重規劃/審查修復/缺口) |
| 預算分艙 | 總預算 30% 鎖給驗證與審查;探索(競技場/洞察/異端)花再兇不得侵入 | 有預算時 |

## 執行留痕(.fable/,由 workflow 自動產生)

fable-emu 執行時會由 Haiku 紀錄員 agent 動態落盤,防止偏移並累積組織知識:

- `.fable/runs/<任務slug>/TASK.md` — 即時任務狀態:完成定義、步驟 checkbox、卡點
- `.fable/DECISIONS.md` — append-only:方案取捨、上報紀錄、審查仲裁(含被駁回的發現與理由)
- `.fable/LESSONS.md` — append-only:被對抗驗證駁回的教訓、執行層漏掉而審查抓到的盲點
- `.fable/KIT-SUGGESTIONS.md` — 結構化條目 `- [pending] 建議(證據:...;日期)`;人審改為 [accepted]/[rejected],僅 accepted 可入法。閉環由 hooks 驅動:Stop hook 逼「寫」(全 tier 收尾檢討)、SessionStart hook 逼「讀」(待審計數 + 蒸餾觸發)、rule-guard 留「證據鏈」(規則檔變更自動記入 DECISIONS)

回饋迴路:下一次任務的理解階段**必讀** LESSONS 與 DECISIONS——教訓跨任務生效,而不是散在對話裡。
`.fable/` 建議進版控(它是團隊知識,不是暫存檔);LESSONS.md 太長時定期蒸餾進 CLAUDE.md 條款或 invariants.md。

## 已知限制(有意接受的殘餘風險)

- **git-guard 是 best-effort 防呆,不是沙箱**:regex 閘門擋常見危險寫法(含旗標位置變形),
  防的是模型失誤,不是蓄意繞過;最後防線是 Claude Code 的 permission mode。擋放樣本由
  `tests/git-guard.Tests.ps1` 鎖定,改 regex 必須跑綠。
- **兩支 Stop gate 有界互讓**:verify-gate(證據)排前、stop-retro-gate(檢討)排後;各自因
  `stop_hook_active` 最多擋一次,單次收尾最壞被擋兩次(證據一次、檢討一次)、不會無限迴圈;
  實際擋幾次取決於 Claude Code 對同一 Stop 事件多 hook 的處理,此屬 harness 行為、非本 kit 可測。
- **verify-gate 看不到 subagent 內的驗證**(transcript 分離):在 workflow 內完成驗證的 session
  被擋時,在回覆中引用該證據(含指令與結果)即可通過下一次收尾。
- **hook 使用相對路徑**:依賴 Claude Code 以專案根目錄執行 hooks(目前行為如此);
  若未來版本改變 cwd 行為,需改為絕對路徑。
- **PostToolUse 與 Stop 已各內建一支 hook**(rule-guard 留痕、stop-retro-gate 收尾檢討);
  「自動 lint」與「codex review gate」仍為選配 —— 追加時見檢查清單第 6 條,勿覆蓋既有 handler。

## 設計原理速記

- 提詞管品質與風格;**不可妥協的環節(驗證次數、投票、預算、危險指令)一律下沉到 harness**。
- Fan-out subagent 與 agent loop 是 Claude Code harness 的能力,模型無關,Opus 4.8 全可用;
  Opus 缺的只是主動性,由 CLAUDE.md 的觸發規則補上。
- Codex/Gemini 只當被呼叫的單體 worker(審查、第二意見),不當編排層。
- 殘差(單發推理深度)用 token 冗餘買回:effort 調高、judge panel、多輪對抗。
- 提詞工藝(合理化警報表、證據閘門措辭、SessionStart 注入)吸收自
  [obra/superpowers](https://github.com/obra/superpowers);
  它是精緻的提詞層,本套件在其上補了它沒有的確定性層(JS workflow + schema + 落盤)。

詳細論述見 `docs/HARNESS.md`。
