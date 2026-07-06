from orders import create_order


def test_ok():
    r = create_order("pen", 2, "Bob@Shop.io")
    assert r["ok"] and r["order"]["contact"] == "bob@shop.io"


def test_bad_email():
    assert create_order("pen", 2, "nope")["ok"] is False


def test_bad_qty():
    assert create_order("pen", 0, "a@b.co")["ok"] is False
