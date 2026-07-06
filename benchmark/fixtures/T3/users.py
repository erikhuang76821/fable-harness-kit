import re


def _valid_email(addr):
    return bool(re.match(r'^[\w.+-]+@[\w-]+\.[\w.]+$', addr or ''))


def register_user(name, email):
    if not name:
        return {"ok": False, "error": "name required"}
    if not _valid_email(email):
        return {"ok": False, "error": "invalid email"}
    return {"ok": True, "user": {"name": name, "email": email.lower()}}
