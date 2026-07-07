# 定價規格(本檔為行為唯一權威;測試僅覆蓋部分案例)

輸入:`unit_price`(單價,整數美分)、`qty`(數量,正整數)、`is_vip`(布林)。

1. **小計**:`subtotal = unit_price * qty`。
2. **數量折扣**:`qty >= 10` 時 10% off。
3. **VIP 折扣**:`is_vip` 時額外 5% off。
4. **疊加方式**:折扣率**加法疊加**——兩者皆符合時總折扣率為 15%,**不是** 0.90 × 0.95。
5. **折後金額**:`total = subtotal × (100 − discount_rate) / 100`,**四捨五入到整數美分(half-up:小數 .5 進位)**。
6. **運費**:**折後** `total >= 10000`(即 $100)免運(shipping = 0),否則 `shipping = 799`。
7. 回傳 dict:`{"subtotal", "discount_rate", "total", "shipping", "grand_total"}`——
   全部整數美分;`discount_rate` 為百分比整數(0 / 5 / 10 / 15);`grand_total = total + shipping`。
