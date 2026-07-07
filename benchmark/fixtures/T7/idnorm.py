def normalize_id(raw):
    """正規化外部 ID:去頭尾空白、轉大寫、去前導零。
    注意:去前導零是 legacy 行為——db.py 的鍵在入庫時即已去前導零。"""
    s = (raw or "").strip().upper()
    if not s:
        raise ValueError("empty id")
    return s.lstrip("0") or "0"
