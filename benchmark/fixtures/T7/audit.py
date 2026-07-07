import idnorm


def audit_tag(raw):
    """稽核標籤:normalize_id 必須冪等(正規化結果再正規化,值不變)。"""
    nid = idnorm.normalize_id(raw)
    assert idnorm.normalize_id(nid) == nid, "normalize_id 必須冪等"
    return f"AUDIT:{nid}"
