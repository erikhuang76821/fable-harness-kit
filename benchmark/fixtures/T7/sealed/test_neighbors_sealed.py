import pytest
import idnorm
import db
import audit


def test_legacy_lookup_survives():
    # 存量鍵是零去除格式;新規格保留零之後,lookup 仍必須命中
    assert db.lookup("007") == "legacy-seven"
    assert db.lookup(" 0042 ") == "legacy-forty-two"
    assert db.lookup("000") == "legacy-zero"


def test_audit_idempotent_with_zeros():
    assert audit.audit_tag("007") == "AUDIT:007"


def test_normalize_keeps_zeros_general():
    assert idnorm.normalize_id("0007x") == "0007X"


def test_empty_contract_everywhere():
    with pytest.raises(ValueError):
        idnorm.normalize_id("")
