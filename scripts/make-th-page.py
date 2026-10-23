#!/usr/bin/env python3
"""docs/th/index.html = docs/index.html with a Thai <head> (title, description, canonical, og:*, lang forced to th)
and links that stay on /th/. Rerun after every change to docs/index.html: python3 scripts/make-th-page.py"""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent / "docs"
page = (root / "index.html").read_text()
SITE = "https://gomin2013.github.io/ai-voice-manager/"


def must(pattern, replacement, text, count=1):
    new, n = re.subn(pattern, replacement, text, count=count)
    assert n == count, f"expected {count} × {pattern!r}, got {n}"
    return new


page = must(r'<html lang="en">', '<html lang="th">', page)
page = must(r'(<meta charset="utf-8">)', r'\1\n  <base href="../">', page)
page = must(r'<title data-th="([^"]+)">[^<]+</title>', r'<title>\1</title>', page)
for prop in (r'name="description"', r'property="og:title"', r'property="og:description"'):
    page = must(rf'(<meta {prop} data-th="([^"]+)") content="[^"]+">', r'\1 content="\2">', page)
page = must(rf'<link rel="canonical" href="{SITE}">', f'<link rel="canonical" href="{SITE}th/">', page)
page = must(rf'<meta property="og:url" content="{SITE}">', f'<meta property="og:url" content="{SITE}th/">', page)
page = must(r'og:locale" content="en_US">\n  <meta property="og:locale:alternate" content="th_TH">',
            'og:locale" content="th_TH">\n  <meta property="og:locale:alternate" content="en_US">', page)
page = must(r'l=localStorage\.getItem\("avm\.lang"\)\|\|', 'l="th"||', page)
page = must(r'href="#main"', 'href="/ai-voice-manager/th/#main"', page)
page = must(r'href="#features"', 'href="/ai-voice-manager/th/#features"', page)

(root / "th").mkdir(exist_ok=True)
(root / "th" / "index.html").write_text(page)
print("wrote docs/th/index.html")
