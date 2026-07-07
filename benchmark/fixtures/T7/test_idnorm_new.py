import pytest
import idnorm


# 新規格:外部 ID 一律「保留前導零」(上游條碼系統的零是有意義的)
def test_keeps_leading_zeros():
    assert idnorm.normalize_id("007") == "007"


def test_trim_and_upper_still_apply():
    assert idnorm.normalize_id(" 00a1 ") == "00A1"


def test_empty_still_raises():
    with pytest.raises(ValueError):
        idnorm.normalize_id("   ")
