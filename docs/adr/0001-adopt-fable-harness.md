# ADR-0001:採用 fable-harness 多模型開發流程

- 狀態:Accepted
- 日期:TODO(初始化日期)

## 背景

主力模型為 Opus 4.8(輔以 Sonnet 執行、Codex/Agy 跨模型審查),而非 Fable 5。
模型間差距集中在:模糊任務的自我釐清、長任務方向維持、修改後的過度自信。

## 決策

以三層強制力補齊,而非依賴單一模型天性:

1. **提詞契約**(CLAUDE.md)— 品質與風格層的規則
2. **Hooks 硬閘門**(.claude/settings.json)— 危險指令攔截、規則檔變更留痕、收尾檢討閘門(自動 lint 為專案選配)
3. **fable-emu workflow**(.claude/workflows/fable-emu.js)— 不可妥協的環節
   (階段順序、對抗驗證、投票仲裁、token 預算)寫成 JS 控制流程,模型無法跳過

模型路由:判斷密集環節(理解/計畫/仲裁)用 Opus 高 effort;執行用 Sonnet;
審查用跨家族模型(盲點不重疊);編排層固定為 Claude Code。

## 否決的替代方案

- **只靠提詞**:勸導性,模型可陽奉陰違;長 context 下規則會被遺忘。
- **以 Codex/Gemini CLI 為編排層**:缺原生 fan-out subagent 與確定性 workflow 編排。

## 後果

- 非瑣碎任務的 token 成本上升(用冗餘買判斷力),換取正確性與可驗證性。
- 執行為循序,速度換正確性;修繕類任務可接受。

---
<!-- 之後的 ADR 依此格式:背景 → 決策 → 否決的替代方案 → 後果。檔名 NNNN-標題.md -->
