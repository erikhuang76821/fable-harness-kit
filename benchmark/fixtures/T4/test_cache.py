import cache


def setup_function(_):
    cache.reset()


def test_isolated_defaults():
    a = cache.get_or_set("a")
    a.append(1)
    assert cache.get_or_set("b") == []  # b 不得被 a 污染


def test_same_key_same_list():
    r1 = cache.get_or_set("r")
    r1.append(5)
    assert cache.get_or_set("r") == [5]
