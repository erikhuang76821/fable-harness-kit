# PITFALLS:傳輸層陷阱手冊(Windows PowerShell 5.1 × 多模型 CLI)

> METHOD.md 講方法論;本檔講**具體會炸的地方**。每一條都在本 kit 的開發或 dogfood 中
> 真實炸過(附實證),不是理論清單。適用對象:在 Windows + PS 5.1 上部署本 kit、
> 或寫任何「PS 腳本 ↔ 原生 CLI ↔ 模型」管線的人。
> 貫穿一切的教訓只有一句:**跨層交接物必須機器可驗;測試環境 ≠ 生產 spawn 環境。**

## 一、編碼(最大宗故障源)

1. **含中文的 .ps1 一律 UTF-8 BOM。**無 BOM 時 PS 5.1 以系統碼頁(CP950)誤解碼,
   中文變亂碼是輕症,重症是 here-string 的結構被弄壞、整檔 parse error。
   注意:AI 代理的檔案寫入工具(如 Claude Code 的 Write)落地的是**無 BOM** UTF-8——
   新建中文 .ps1 後必須補 BOM(`[System.IO.File]::WriteAllText` + `UTF8Encoding($true)`);
   編輯既有帶 BOM 檔案則安全。
   (實證:2026-07-07,upstream-suggestions 測試首跑 parse 爆,錯誤訊息現「撱箄降」式亂碼)

2. **hook 輸出中文必須顯式 `[Console]::OutputEncoding = UTF8`。**Claude Code 以 UTF-8
   讀 hook stdout,PS 5.1 預設用主控台碼頁輸出——使用者看到的 nudge 全是「�ʤu�e」。
   本 kit 六支 hooks 開頭已內建此行;自己加 hook 時照抄。
   (實證:2026-07-07 dogfood 首日)

3. **互動 console 正常 ≠ spawn 子行程正常。**碼頁問題只在「被程式 spawn、輸出被管道
   接走」時現形,手動跑永遠測不到。推論:測中文輸出的測試,斷言走**檔案內容**
   (讀時指定編碼),不要斷言子行程 stdout。
   (實證:tests/upstream-suggestions.Tests.ps1 的設計即因此)

## 二、PS → 原生執行檔傳參

4. **參數不得內嵌雙引號。**PS 5.1 對原生執行檔的引號轉義不可靠,含引號的複雜參數
   會被拆爛。修法:把內容寫進暫存腳本檔,傳**路徑**,用 `-File` / bash 執行該檔。

5. **`powershell -File` 不解析陣列參數。**`-Tasks a,b,c` 到腳本裡是字串 `"a,b,c"`,
   不是陣列——`param([string[]])` 也救不了。修法:以字串接收,腳本內自行拆逗號。
   (實證:run-benchmark.ps1,commit 3f2afed)

6. **codex CLI:先 `cd` 到受信任目錄,stdin 導 `/dev/null`。**否則信任提示掛起或拒跑,
   headless 場景直接空轉。

7. **agy CLI:`--model` 必須在 `-p` 之前**,順序錯會被靜默忽略。橋接 agy 做審查時必須
   **echo 接地**:要求審查者先複述題目關鍵事實,複述不出即整份作廢——半壞的橋接層
   會被 schema 逼著編造「格式正確的空審查」,虛假背書比無審查更糟(見 METHOD.md 原則三)。

## 三、契約同步(regex / 標記 / 狀態)

8. **模板待填標記必須與偵測 regex 同一形式,並用契約測試鎖住。**invariants 模板寫
   「TODO 範例:」而偵測 regex 是 `TODO\(`,doctor 對未填模板誤報全綠——守門員看不見
   要守的東西。現行正典:標記一律 `TODO(...)`,tests/template-todo.Tests.ps1 以
   「任何 TODO 字樣計數 == `TODO(` 計數」鎖住整類。
   (實證:2026-07-07 RedmineCatch 整合;commit f37c788)

9. **留痕檔的標記語彙要與消費它的腳本判準同步。**KIT-SUGGESTIONS 的狀態標記
   ([pending]/[accepted]/[upstreamed]/[local]/[accepted→已入法 日期])是
   upstream-suggestions.ps1 的**輸入格式**,自創寫法會讓條目被重複回流或漏掉;
   對同檔的程式化改寫要以行號定位,不要以內容比對(同名首行會誤傷)。
   (實證:commit e3498c8)

10. **狀態交接物用單源 JSON + 格式鐵則,不靠模型自律。**中文狀態行會被弱模型翻譯、
    改寫、加解釋,exact-equality 判定必炸。修法:狀態單源(status-contract.json)、
    regex 後備、語意判定取代字面比對。
    (實證:fable-run 監督器誤判截斷白燒兩次續跑;安全閥 110 秒白燒——均金絲雀實跑抓到)
