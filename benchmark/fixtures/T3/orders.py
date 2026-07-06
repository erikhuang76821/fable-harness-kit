import re


def _valid_email(addr):
    return bool(re.match(r'^[\w.+-]+@[\w-]+\.[\w.]+$', addr or ''))


def create_order(item, qty, contact_email):
    if not item or qty <= 0:
        return {"ok": False, "error": "invalid item/qty"}
    if not _valid_email(contact_email):
        return {"ok": False, "error": "invalid email"}
    return {"ok": True, "order": {"item": item, "qty": qty, "contact": contact_email.lower()}}
