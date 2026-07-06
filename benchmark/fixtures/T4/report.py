from cache import get_or_set


def add_row(row):
    rows = get_or_set("report_rows", [])
    rows.append(row)
    return rows


def row_count():
    return len(get_or_set("report_rows", []))
