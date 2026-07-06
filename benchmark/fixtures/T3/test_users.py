from users import register_user


def test_ok():
    r = register_user("amy", "Amy@Example.com")
    assert r["ok"] and r["user"]["email"] == "amy@example.com"


def test_bad_email():
    assert register_user("amy", "not-an-email")["ok"] is False


def test_missing_name():
    assert register_user("", "a@b.co")["ok"] is False
