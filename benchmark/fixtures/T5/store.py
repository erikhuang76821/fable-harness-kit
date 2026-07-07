_stock = {}


def set_stock(sku, qty):
    _stock[sku] = qty


def available(sku):
    return _stock.get(sku, 0)


def take(sku, qty):
    if _stock.get(sku, 0) < qty:
        raise ValueError("insufficient stock")
    _stock[sku] -= qty


def release(sku, qty):
    """把 qty 個 sku 釋放回庫存(預約過期/取消時呼叫)。"""
    _stock[sku] = _stock.get(sku, 0) + qty


def reset():
    _stock.clear()
