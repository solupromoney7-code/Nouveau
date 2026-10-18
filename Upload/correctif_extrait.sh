#!/bin/bash
# Correctif : le formulaire d'extrait ne perdait plus les inscriptions
set -e
cd "$(git rev-parse --show-toplevel)"
python3 - <<'PY'
def sub(path, old, new):
    s = open(path).read()
    if new in s:
        return
    assert old in s, (path, old)
    open(path, 'w').write(s.replace(old, new))
sub('lib/antibot.js', 'return Boolean(body?.website);', 'return Boolean(body?.hpField);')
sub('pages/e/[slug].js', 'website: form.hp,', 'hpField: form.hp,')
sub('pages/p/[slug].js', 'website: form.hp,', 'hpField: form.hp,')
sub('pages/inscription.js', 'website: form.website,', 'hpField: form.website,')
print("OK : correctif appliqué")
PY
