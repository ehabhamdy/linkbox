from app.utils.id import generate_short_id
import re

def test_generate_short_id_default_length():
    _id = generate_short_id()
    assert len(_id) == 6
    assert re.match(r'^[A-Za-z0-9]{6}$', _id)

def test_generate_short_id_custom_length():
    _id = generate_short_id(10)
    assert len(_id) == 10

def test_generate_short_id_invalid():
    import pytest
    with pytest.raises(ValueError):
        generate_short_id(0)
