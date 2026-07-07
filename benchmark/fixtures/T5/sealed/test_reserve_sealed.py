import store
import reserve


def setup_function(_):
    store.reset()
    reserve.reset()


def test_unexpired_untouched():
    store.set_stock("a", 10)
    r1 = reserve.reserve("a", 3, ts=1000)
    r2 = reserve.reserve("a", 2, ts=1400)
    reserve.expire_reservations(now=1350)  # r1 存活 350 過期;r2 尚未
    assert store.available("a") == 8
    act = reserve.active_reservations()
    assert len(act) == 1 and act[0] is r2


def test_idempotent_double_expire():
    store.set_stock("a", 10)
    reserve.reserve("a", 4, ts=0)
    reserve.expire_reservations(now=1000)
    reserve.expire_reservations(now=2000)
    assert store.available("a") == 10  # 不得重複釋放


def test_boundary_exact_ttl_expires():
    store.set_stock("a", 5)
    reserve.reserve("a", 5, ts=0)
    reserve.expire_reservations(now=300)  # 存活「達」TTL(含)即過期
    assert store.available("a") == 5


def test_mixed_skus():
    store.set_stock("a", 5)
    store.set_stock("b", 5)
    reserve.reserve("a", 2, ts=0)
    reserve.reserve("b", 3, ts=250)
    reserve.expire_reservations(now=400)
    assert store.available("a") == 5   # a 過期釋放
    assert store.available("b") == 2   # b 存活 150,不動
