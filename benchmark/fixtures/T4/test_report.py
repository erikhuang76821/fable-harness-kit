import cache
from report import add_row, row_count


def setup_function(_):
    cache.reset()


def test_add_and_count():
    add_row({"id": 1})
    add_row({"id": 2})
    assert row_count() == 2


def test_rows_persist_same_identity():
    rows = add_row({"id": 1})
    assert cache.get_or_set("report_rows") is rows
