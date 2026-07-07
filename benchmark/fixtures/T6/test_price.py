from price import quote


def test_no_discount_with_shipping():
    q = quote(unit_price=500, qty=3, is_vip=False)
    assert q == {"subtotal": 1500, "discount_rate": 0, "total": 1500, "shipping": 799, "grand_total": 2299}


def test_bulk_discount():
    q = quote(unit_price=1000, qty=20, is_vip=False)
    assert q["discount_rate"] == 10
    assert q["total"] == 18000
    assert q["shipping"] == 0
