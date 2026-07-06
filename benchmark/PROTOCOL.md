# Benchmark PROTOCOL(預註冊,動手前寫死——改動本檔需在 git 留下獨立 commit)

## 假設(受測宣稱)

H1:「kit 化 Opus(harness 全開,含路由/workflow/hooks)在同一批任務上,品質不輸裸 Fable 5,且成本 ≤ 裸 Fable 5。」
虛無假設 H0:裸 Fable 5 在品質或成本效率上顯著優於 kit 化 Opus。

## 利益衝突聲明

本 kit 的文件與機制大半由 Fable 5 級模型設計(見 git log)。因此:
- **盲評裁判一律非 Claude 家族**(codex + agy/Gemini),echo 接地,雙裁判分歧時記錄分歧不強行合成;
- 兩臂產出以隨機代號(X/Y)匿名,映射檔在評分完成前不得進入裁判 context;
- 本協議先於執行寫死(預註冊),避免事後挑選指標。

## 實驗臂

- **A(基線)**:裸 Fable 5,headless `claude -p`,無 kit 檔案,工具白名單與 B 相同。
- **B(受測)**:kit 化 Opus——init.ps1 鋪滿 kit(CLAUDE.md 路由 + hooks + workflow),經 fable-run 監督執行,分級由 kit 自行路由(不強迫 fable-emu;這測的是「kit as deployed」)。
- 兩臂拿到**逐字相同**的任務文字;各任務獨立 fresh workdir(含 git baseline commit)。

## 任務(4 題,難度遞增,驗收全部機器可判)

| ID | 類型 | 初始狀態 | 驗收(ACCEPT.ps1) |
|---|---|---|---|
| T1 | 單點 bugfix(頁數計算 off-by-one) | 測試紅 | pytest 全綠 |
| T2 | 依測試實作功能(slugify) | 測試紅(NotImplemented) | pytest 全綠 |
| T3 | 跨模組重構(重複驗證邏輯抽共用) | 測試綠(重構不得弄破) | pytest 全綠 + validators.py 含 is_valid_email + 兩模組皆 import 之 |
| T4 | 回歸風險 bugfix(可變預設值污染;另一消費者依賴既有行為) | cache 測試紅、report 測試綠 | pytest 全綠(含 report 不回歸) |

## 指標

- **主要**:驗收通過率(ACCEPT.ps1 exit 0)。
- **次要 1**:成本(stream-json result 的 `total_cost_usd` 加總,不自行估價)。
- **次要 2**:牆鐘時間。
- **次要 3**:盲評品質分(0-10:測試外正確性、範圍紀律、程式品質),雙裁判。

## 判定規則(預註冊)

- 任一臂驗收未過 → 該任務品質分不列入,通過率單獨報。
- H1 成立條件:B 通過率 ≥ A,且 B 盲評均分 ≥ A − 0.5,且 B 成本總和 ≤ A 成本總和。
- 任何一項不滿足 → 如實回報哪一項、差多少;**不得改判定規則遷就結果**。

## 程序

1. `run-benchmark.ps1 -Tasks T1[,T2,...]` 逐任務×臂執行,結果落 `results/*.jsonl` + workdir artifact。
2. `judge.ps1 -Results <jsonl>` 匿名化兩臂 diff,送雙裁判盲評,原始回覆全文留檔。
3. 揭盲、彙整、對照判定規則出報告;報告含每筆原始數據路徑。

## 已知限制(誠實邊界)

- n=4 任務、每格 1 run:這是**校準級**實驗,不是統計顯著性實驗;結論措辭必須反映之。
- 任務全為 Python 小型 fixture,不代表大型 repo 的長程任務(那是 Fable 的已知強項,見 TIER3-FRONTIER)。
- 裸 Fable 臂沒有 hooks 的防護,若其危險行為導致失敗,如實計入(這正是 kit 的價值主張之一)。
