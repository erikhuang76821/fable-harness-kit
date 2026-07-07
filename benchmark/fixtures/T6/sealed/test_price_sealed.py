from price import quote


def test_boundary_exactly_ten_units():
    q = quote(unit_price=100, qty=10, is_vip=False)
    assert q["discount_rate"] == 10  # 恰好 10 件即符合


def test_vip_only():
    q = quote(unit_price=200, qty=2, is_vip=True)
    assert q["discount_rate"] == 5
    assert q["total"] == 380


def test_additive_not_multiplicative():
    q = quote(unit_price=100, qty=10, is_vip=True)
    assert q["discount_rate"] == 15
    assert q["total"] == 850  # 加法疊加 1000*0.85;乘法疊加會得 855


def test_rounding_half_up():
    q = quote(unit_price=333, qty=10, is_vip=True)
    # 3330 * 0.85 = 2830.5 → half-up 進位 2831(bankers rounding 會得 2830)
    assert q["total"] == 2831


def test_free_shipping_threshold_post_discount():
    # 折後恰好 10000 → 免運
    q = quote(unit_price=1000, qty=10, is_vip=False)  # 10000*0.9=9000 → 運費 799
    assert q["shipping"] == 799
    q2 = quote(unit_price=1112, qty=10, is_vip=False)  # 11120*0.9=10008 → 免運
    assert q2["shipping"] == 0
    q3 = quote(unit_price=10000, qty=1, is_vip=False)  # 無折扣 10000 → 恰達門檻免運
    assert q3 == {"subtotal": 10000, "discount_rate": 0, "total": 10000, "shipping": 0, "grand_total": 10000}
