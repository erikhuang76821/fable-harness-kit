from slug import slugify


def test_lowercase():
    assert slugify("Hello World") == "hello-world"


def test_strip_punctuation():
    assert slugify("Hello, World!") == "hello-world"


def test_collapse_spaces_and_dashes():
    assert slugify("a  b---c") == "a-b-c"


def test_leading_trailing():
    assert slugify("  --Hello--  ") == "hello"


def test_empty_and_symbol_only():
    assert slugify("") == "n-a"
    assert slugify("!!!") == "n-a"


def test_numbers_kept():
    assert slugify("Top 10 Tips") == "top-10-tips"
