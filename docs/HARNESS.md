# 多模型開發 Harness 設計指南

> 目標:Opus 4.8(主力)+ Sonnet 5/4.6(執行)+ Codex/Agy(跨模型審查),
> 透過「提詞契約 + Harness 硬機制 + Workflow 腳本」三層強制力,逼近 Fable 級思考維度。
> 核心等式:**Opus 4.8 + JS Workflow 骨架(編排判斷的預編譯)≈ Fable 5**

---

## 一、提詞限制條款(單一事實來源:kit 的 CLAUDE.md)

提詞只能管「模型願意遵守時的行為品質」。條款本文(反腦補、範圍、階段契約、誠實、
自主情境、邊界、合理化警報表)**以 CLAUDE.md 為準,本檔不重複收錄以免版本漂移**。
這裡只保留 CLAUDE.md 放不下的設計論證:

### 1.1 提詞的天花板(這些提詞管不住,必須交給 harness)

| 提詞管不住的事 | 原因 | 交給哪個 harness 機制 |
|---|---|---|
| 「一定要驗證 N 次 / 投票過半」 | 模型會少做、早收工 | Workflow JS 迴圈與 `filter().length >= N` |
| 長 context 後遺忘開頭的規則 | context 衰減是物理限制 | 每步重新注入(fable-emu 的 journal)、/handoff 切段 |
| 危險指令(push、reset --hard、rm) | 勸導擋不住一次失誤 | PreToolUse hook 硬擋(`.claude/hooks/git-guard.ps1`) |
| 改完 code 忘記跑 lint/test | 「記得」不可靠 | PostToolUse hook 自動跑(選配,需依專案配置) |
| 輸出格式完整性 | 「請輸出 JSON」會漏欄位 | Workflow `schema`(工具層驗證,不符自動重試) |
| token 花費上限 | 模型沒有花費概念 | Workflow `budget` 硬上限 |
| 「每次都要做 X」類自動化 | 模型記憶不跨 session | hooks / CLAUDE.md,不是口頭約定 |

**設計原則:凡是「不可妥協」的環節,從提詞搬進 harness;提詞只留品質與風格層的指引。**

---

## 二、建議的 Harness 配置

### 2.1 編排層:Claude Code(模型無關)

Fan-out subagent、Workflow 編排、hooks、skills、permission mode 全是
**Claude Code harness 的能力,不是 Fable 專屬**。Opus 4.8 / Sonnet 跑在同一 harness 上,
工具一個不少;差別只在主動性 —— 由 CLAUDE.md 的觸發規則補
(分級路由 Tier 0-3、費用信封、交付優先、卡關改道,**以 CLAUDE.md「任務分級路由」為準**,不在此重複)。

**校準警語**:本套件的詳盡條款是 **Opus 級校準**——官方指南證實「過度指令性的提詞會降低
Fable 級模型的輸出品質,但正是 Opus 需要的」。若編排模型換成 Fable 級,先去指令化
(de-prescribe)再用;Tier 3 深潛模板(docs/TIER3-FRONTIER.md)即為去指令化的參考形態——
難題入口對任何強模型都要留白。

### 2.2 Repo 資料結構(讓 context 品質取代模型智力)

```
repo/
├── CLAUDE.md            # 硬規則:分級路由 + 決策核心摘要 + 提詞限制條款 + build/test 指令
├── CONTEXT.md           # 領域語言字典 + 架構地圖(寫「為什麼」,不寫「是什麼」)
├── fable-run.ps1        # headless Tier 2/3 監督式執行器(截斷偵測 + 續跑)
├── docs/
│   ├── DECISION-CORE.md # 決策核心完整版:授權/資訊裁決/判準,含正反例與實證標記
│   ├── TIER3-FRONTIER.md# 前沿模式:深潛去指令化模板 + 競試用法(僅 Tier 3 讀)
│   ├── adr/             # 決策紀錄:為什麼這樣設計、否決過什麼方案
│   └── invariants.md    # 不變量:「X 永遠不能為 null」「A 必先於 B」——弱模型的護欄
└── .claude/
    ├── workflows/
    │   ├── fable-emu.js      # Tier 2 編排:理解→計畫→執行→跨審→完整性→檢討
    │   └── deep-attempts.js  # Tier 3 競試:N 個平行深潛 + 裁判實測擇優
    ├── hooks/           # 四支硬閘門:session-brief / git-guard / rule-guard / stop-retro-gate
    ├── skills/          # (選配)固化流程:diagnose、tdd、handoff...(套件不內建)
    └── settings.json    # hooks 配置(下節)
```

### 2.3 Hooks(硬閘門,零信任層)

| Hook | 用途 | 狀態 |
|---|---|---|
| SessionStart | 注入核心鐵律 + LESSONS/DECISIONS + 待審建議計數 + 蒸餾觸發(compact 後重注) | ✅ 套件內建 |
| UserPromptSubmit | 每回合一行輕推(prompt-nudge),對抗長 session 規則衰減;建 `.claude/nudge-off` 可關 | ✅ 套件內建 |
| PreToolUse | 擋危險 git / 遞迴刪除指令(git-guard) | ✅ 套件內建 |
| PostToolUse(Edit/MultiEdit/Write) | 規則檔變更自動留痕 DECISIONS.md(rule-guard) | ✅ 套件內建 |
| Stop ①(verify-gate) | 改了程式檔卻無測試痕跡 → 擋一次,補證據或明說「已修改、未驗證」 | ✅ 套件內建 |
| Stop ②(stop-retro-gate) | 有修改的 session 收尾前強制檢討一次 | ✅ 套件內建 |
| PostToolUse(lint/typecheck 自動跑) | 錯誤直接回饋給模型 | ⚠️ 選配:在**現有 PostToolUse 陣列追加** handler,勿覆蓋 rule-guard |

hooks 的行為契約由 `tests/`(Pester)鎖定——改 hook 必須跑綠才算完成;
兩支 Stop gate 各擋一次,任一擋過後 `stop_hook_active` 使另一支放行(單次收尾最多被擋一次)。

### 2.4 模型路由(判斷密度決定模型等級)

| 環節 | 模型 | 理由 |
|---|---|---|
| 理解 / 計畫 / 仲裁 | Opus 4.8(effort high~xhigh) | 判斷密度最高;必要時換 judge panel(3 方案評分) |
| 逐步執行 | Sonnet 5 / 4.6 | 計畫已收窄任務,執行不需頂級判斷 |
| 對抗式審查 | Codex + Agy(Gemini) | 跨家族盲點不重疊;prompt 立場設為「預設有錯,盡力反駁」 |
| 機械性掃描 / 整理 | Haiku 4.5 | 便宜、量大 |

**低成本預設路由(日常補充,吸收自 Miguok/fable-harness 的直覺版)**:
- 主迴圈是指揮官,不做粗活:預估要讀 >10 個檔、或「找出所有 X / 盤點整個 Y」型任務 → 派 Explore(haiku),只收結論 + file:line,不收原始檔傾倒。
- 瑣碎單步(改一行、看一個檔)主迴圈直接做——委派 overhead 反而更貴。
- 推理/架構/仲裁留在當前模型;非瑣碎的編寫/重構派 sonnet;批次/搜尋/整理派 haiku。

### 2.5 Codex / Gemini 的定位

- 兩者原生的 fan-out 與確定性編排能力遠弱於 Claude Code,
  **只當被呼叫的單體 worker(審查者、第二意見、rescue),不當編排層**。
- 若獨立使用:CLAUDE.md 的等價物是 Codex 的 AGENTS.md / Gemini 的 GEMINI.md,
  提詞限制條款(第一節)可原樣移植;但 Workflow 級強制力無法移植,
  這正是編排層留在 Claude Code 的原因。

### 2.6 Agent loop 的三種形態(都已可用,按需選)

1. **步內修復迴圈**:執行→對抗驗證→駁回→帶著駁回理由重做,N 次後升級強模型
   (fable-emu 已內建)。
2. **loop-until-dry**:未知數量的發現型任務(找 bug、找漏項),
   連續 K 輪無新發現才停 —— 寫成 `while (dry < K)`,封死「找幾個就收工」。
3. **跨 session 迴圈**:/loop skill 或排程任務,適合守望型工作(盯 CI、定期巡檢)。

---

## 三、一頁總結

- **提詞**管品質與風格,天花板在「勸導性」;不可妥協的環節一律下沉到 harness。
- **Harness(Claude Code)**提供 fan-out、Workflow、hooks —— 模型無關,Opus 4.8 全部可用。
- **Workflow 腳本**是編排判斷的預編譯:Fable 的「哪裡該懷疑、懷疑幾次、誰仲裁、何時收斂」
  凍結成 JS 之後,Opus 只需做局部判斷,而局部判斷正是它與 Fable 差距最小之處。
- 殘差(單發推理深度)用 token 冗餘買回:effort 調高、judge panel、多輪對抗。
