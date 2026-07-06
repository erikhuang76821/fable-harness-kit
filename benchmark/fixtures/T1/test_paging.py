import pytest
from paging import page_count


def test_exact_division():
    assert page_count(9, 3) == 3


def test_with_remainder():
    assert page_count(10, 3) == 4


def test_zero_items():
    assert page_count(0, 3) == 0


def test_invalid_per_page():
    with pytest.raises(ValueError):
        page_count(5, 0)
