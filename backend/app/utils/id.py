import secrets
import string

ALPHABET = string.ascii_letters + string.digits

def generate_short_id(length: int = 6) -> str:
    """Generate a URL-safe short id comprised of letters+digits.

    Uses secrets.choice for cryptographic randomness. Default length 6 yields
    62^6 (~56B) possibilities.
    """
    if length <= 0:
        raise ValueError("length must be > 0")
    return ''.join(secrets.choice(ALPHABET) for _ in range(length))
