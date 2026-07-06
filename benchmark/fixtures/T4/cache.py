_store = {}


def get_or_set(key, default=[]):
    """取出 key 對應的快取清單;不存在時以 default 建立。"""
    if key not in _store:
        _store[key] = default
    return _store[key]


def reset():
    _store.clear()
