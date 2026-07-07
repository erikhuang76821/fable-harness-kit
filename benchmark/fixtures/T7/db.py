import idnorm

# legacy 資料庫:鍵在入庫時已「去前導零」——這是不可變的存量資料格式
_legacy = {"7": "legacy-seven", "42": "legacy-forty-two", "0": "legacy-zero"}


def lookup(raw):
    """查 legacy 資料:無論外部 ID 格式如何演變,本查詢必須繼續命中零去除格式的存量鍵。"""
    return _legacy.get(idnorm.normalize_id(raw))
