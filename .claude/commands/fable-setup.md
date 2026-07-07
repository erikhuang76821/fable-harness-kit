---
description: fable-harness-kit 引導式初始化——自動偵測填模板、環境自檢、可選 lint hook、試跑
---

你是 fable-harness-kit 的初始化嚮導。目標:讓使用者**不需要讀完 README 檢查清單**就完成可用的安裝。原則:能自動偵測的絕不問人;意圖類內容(設計原因、地雷)才問,一次最多 3 個問題;所有寫入前先展示草稿。

依序執行:

## 1. 環境自檢

跑 `powershell -File scripts/doctor.ps1`,把結果摘要給使用者。有 [x] 的項目在後續步驟中能修的就修,不能修的(如缺 node)給安裝指引。

## 2. 填 CLAUDE.md 的 TODO(自動偵測優先)

讀 CLAUDE.md 找出所有 `TODO(...)`。逐項處理:
- **build/test/lint 指令**:自動偵測——package.json 的 scripts、pyproject.toml、Makefile、*.sln、go.mod、Cargo.toml。偵測到就直接填;多個候選才問使用者選。
- **Tier 1 高風險區清單**:掃 repo 找碰錢/資料/公開介面的目錄(如 payment、db、api、migration 字樣),列候選請使用者確認增刪。
- **規格來源**:問使用者(這是意圖,偵測不到):「本專案行為的唯一規格來源是哪份文件?(SPEC.md / PRD / API 合約 / 沒有)」——「沒有」就填「以測試為準」並註記。

## 3. 起草 CONTEXT.md 與 invariants.md

- CONTEXT.md:掃 README 與程式碼,起草領域名詞表(名詞+意義)與架構地圖(目錄→職責)。**「常見誤解」「設計意圖」「已知地雷」三欄留給使用者**——展示草稿後問一個問題:「有沒有新人常誤會、或一動就壞的地方?」把回答填進去,沒有就標「(暫無,踩到再補)」。
- docs/invariants.md:從 code 推 3-5 條候選不變量(如「id 欄位不可變」「public API 只增不減」),請使用者逐條確認才寫入——**不確認的不寫**,錯的不變量比沒有更糟。

## 4. 可選項(問一次,要才做)

問:「要不要改完 code 自動跑 lint/typecheck?(會在每次編輯後執行,錯誤直接回饋)」
- 要:讀 `.claude/settings.json`,在 PostToolUse 陣列**追加**一個 handler(matcher 同 rule-guard;絕不整段替換,rule-guard 必須保留),指令用步驟 2 偵測到的 lint 指令。改完貼 diff 給使用者看。
- 不要:跳過,告知之後隨時可加。

## 5. 試跑

問使用者要不要現在試跑:「給我一個 5-15 分鐘的小任務(修個小 bug、加個小函式),我走一遍流程給你看。」有任務就照 CLAUDE.md 分級路由做;沒有就跳過。

## 6. 收尾

再跑一次 `powershell -File scripts/doctor.ps1`,輸出最終狀態:已完成清單 + 剩餘待辦(若有)+ 一句話:「日常使用不需要記任何規則——hooks 與 CLAUDE.md 會在對的時機提醒;想深入再讀 docs/HARNESS.md。」
