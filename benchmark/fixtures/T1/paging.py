def page_count(total_items, per_page):
    """回傳容納 total_items 筆資料所需的頁數(每頁 per_page 筆)。"""
    if per_page <= 0:
        raise ValueError("per_page 必須為正數")
    return total_items // per_page
