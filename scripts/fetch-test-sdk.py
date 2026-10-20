"""Fetch the exact official SDK used by the isolated cloud guard regression."""
import hashlib
from pathlib import Path
import urllib.request

URL = 'https://tb5.bdstatic.com/ai-game/tieba-game.umd.js'
SHA256 = 'c45fa2f5b48055bcdbd68132695fe0af54c26e3f4635eec961e3b83f0d00f194'
TARGET = Path(__file__).resolve().parent.parent / '.cache' / 'tieba-game.umd.js'


def matches(content):
    return hashlib.sha256(content).hexdigest() == SHA256


if TARGET.exists() and matches(TARGET.read_bytes()):
    print('Official test SDK cache verified.')
else:
    with urllib.request.urlopen(URL, timeout=30) as response:
        data = response.read()
    if not matches(data):
        raise SystemExit('Official SDK changed. Inspect the new SDK before updating the pinned hash.')
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_bytes(data)
    print('Official test SDK downloaded and verified.')
