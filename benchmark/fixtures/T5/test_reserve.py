import store
import reserve


def setup_function(_):
    store.reset()
    reserve.reset()


def test_reserve_takes_stock():
    store.set_stock("a", 10)
    reserve.reserve("a", 4, ts=1000)
    assert store.available("a") == 6


def test_expire_releases_stock():
    store.set_stock("a", 10)
    reserve.reserve("a", 4, ts=1000)
    reserve.expire_reservations(now=1301)
    assert store.available("a") == 10
    assert reserve.active_reservations() == []
