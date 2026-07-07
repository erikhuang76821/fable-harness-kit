import store

TTL_SECONDS = 300

_reservations = []  # 每筆:{"sku", "qty", "ts", "active"}


def reserve(sku, qty, ts):
    store.take(sku, qty)
    r = {"sku": sku, "qty": qty, "ts": ts, "active": True}
    _reservations.append(r)
    return r


def active_reservations():
    """回傳活躍預約,依建立順序。"""
    return [r for r in _reservations if r["active"]]


def reset():
    _reservations.clear()
