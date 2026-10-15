#!/usr/bin/env python3
"""Screenshot every tab of the observ-viz boards on a live Grafana (docs gallery).

Runs inside the Playwright image - see `just docs-shots`:
  SHOTS_GRAFANA_URL     the Grafana to render (default https://grafana.monlab.newt.cz)
  SHOTS_GRAFANA_TOKEN   a service-account token that can view the boards
  shots.py OUT [--uids a,b] [--width 1600] [--limit N] [--jobs N] [--show-logs]

Boards (default): every board a docs/observ-libs page names (`Dashboard uid`),
the service, base and scenario boards (observ-viz-*, base-*, scn-*,
cluster-detail) and the chart-type reference boards (folder "Panels") - the
ones that exist on that Grafana. Upstream mixin boards are left out.

Writes OUT/<uid>/<NN>-<tab>.webp (one full-height shot per visible tab, or one
per board without tabs) and OUT/manifest.json:
  {"grafana": url, "rendered": iso-time, "logsMasked": bool,
   "boards": [{uid, title, folder, tabs: [{title, slug, file, loading?}]}]}
(`loading`: queries still ran when the shot was taken.)
"""
import argparse
import datetime
import glob
import io
import json
import multiprocessing
import os
import re
import sys
import urllib.parse
import urllib.request

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def api(url, token, path):
    req = urllib.request.Request(url + path, headers={'Authorization': 'Bearer ' + token})
    return json.load(urllib.request.urlopen(req, timeout=30))


def wanted_boards(url, token, only):
    found = api(url, token, '/api/search?' + urllib.parse.urlencode({'type': 'dash-db', 'limit': 5000}))
    if only:
        return [b for b in found if b['uid'] in only]
    pages = ' '.join(open(f).read() for f in glob.glob(os.path.join(ROOT, 'docs/observ-libs/*.md')))
    doc_uids = set(re.findall(r'Dashboard uid `([^`]+)`', pages))
    prefixes = ('observ-viz-', 'base-', 'scn-')
    keep = [b for b in found
            if b['uid'] in doc_uids or b['uid'].startswith(prefixes) or b['uid'] == 'cluster-detail'
            or b.get('folderTitle') == 'Panels']
    return sorted(keep, key=lambda b: (b.get('folderTitle', ''), b['title']))


def slugify(s):
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-') or 'tab'


def loaded(page, seconds, quiet=4):
    """Wait until no query has run for `quiet` seconds: the refresh picker shows
    "Cancel" while queries run, and a tab's queries start a second or two after
    the click. False when that does not happen within `seconds`."""
    calm = 0.0
    for _ in range(int(seconds * 2)):
        if page.locator('button:has-text("Cancel")').count() == 0:
            calm += 0.5
            if calm >= quiet:
                return True
        else:
            calm = 0.0
        page.wait_for_timeout(500)
    return False


def settle(page, width, max_height=14000, rounds=6, patience=120):
    """Wait for the queries to finish, growing the viewport to the page height
    so lazily loaded panels further down render too. False when queries still
    run after `patience` seconds (the shot then shows loading panels)."""
    try:
        page.wait_for_load_state('networkidle', timeout=30000)
    except Exception:
        pass
    done = False
    for _ in range(rounds):
        done = loaded(page, patience)
        height = min(max(page.evaluate('document.body.scrollHeight'), 900), max_height)
        if height == page.viewport_size['height']:
            break
        page.set_viewport_size({'width': width, 'height': height})
    page.wait_for_timeout(1000)  # let the last panels paint
    return done


def stable_tabs(page, quiet=4, timeout=40):
    """Tab titles once the bar stops changing: presence-gated tabs appear only
    after their hidden variables resolve, seconds after the first paint."""
    last, same = None, 0
    for _ in range(timeout):
        tabs = page.locator('[role="tab"]')
        titles = [tabs.nth(i).inner_text().strip() for i in range(tabs.count())]
        same = same + 1 if titles == last else 0
        if same >= quiet:
            return titles
        last = titles
        page.wait_for_timeout(1000)
    return last or []


def open_tab(page, title):
    """Click a tab by its title and confirm it is the selected one."""
    tab = page.get_by_role('tab', name=title, exact=True).first
    tab.click()
    page.wait_for_timeout(500)
    if tab.get_attribute('aria-selected') != 'true':
        raise RuntimeError(f'tab {title!r} did not open')


def tab_entry(title, slug, file, done):
    return {'title': title, 'slug': slug, 'file': file, **({} if done else {'loading': True})}


WEBP_MAX = 16383  # WebP's largest side, in pixels


# log lines can carry public addresses and logins: by default the gallery
# shows the log panels but masks their lines
LOG_LINES = '.unwrapped-log-line, .log-line-body, .logs-rows, [data-testid="logRows"]'


def shoot(page, path, mask_logs=True):
    mask = [page.locator('[data-testid="data-testid panel content"]').filter(has=page.locator(LOG_LINES))] if mask_logs else []
    png = page.screenshot(full_page=True, type='png', mask=mask, mask_color='#3a3d45')
    img = Image.open(io.BytesIO(png)).convert('RGB')
    if img.height > WEBP_MAX:  # a very long tab: scale it down to fit
        img = img.resize((img.width * WEBP_MAX // img.height, WEBP_MAX), Image.LANCZOS)
    img.save(path, 'WEBP', quality=80, method=6)


def render(out, url, token, width, mask_logs, boards, worker=0, workers=1):
    """Shoot every tab of `boards` (this worker's share) -> manifest entries."""
    entries = []
    tag = f'w{worker + 1} ' if workers > 1 else ''
    with sync_playwright() as p:
        browser = p.chromium.launch()
        ctx = browser.new_context(viewport={'width': width, 'height': 900}, extra_http_headers={'Authorization': 'Bearer ' + token})
        page = ctx.new_page()
        for n, b in enumerate(boards, 1):
            uid = b['uid']
            entry = {'uid': uid, 'title': b['title'], 'folder': b.get('folderTitle', ''), 'tabs': []}
            os.makedirs(os.path.join(out, uid), exist_ok=True)
            try:
                page.set_viewport_size({'width': width, 'height': 900})
                page.goto(f'{url}/d/{uid}?orgId=1&kiosk', wait_until='domcontentloaded', timeout=90000)
                done = settle(page, width)
                titles = stable_tabs(page)
                if not titles:
                    file = f'{uid}/00-board.webp'
                    shoot(page, os.path.join(out, file), mask_logs)
                    entry['tabs'].append(tab_entry(b['title'], 'board', file, done))
                for i, title in enumerate(titles):
                    page.set_viewport_size({'width': width, 'height': 900})
                    open_tab(page, title)
                    done = settle(page, width)
                    file = f'{uid}/{i:02d}-{slugify(title)}.webp'
                    shoot(page, os.path.join(out, file), mask_logs)
                    entry['tabs'].append(tab_entry(title, slugify(title), file, done))
                slow = [t['title'] for t in entry['tabs'] if t.get('loading')]
                print(f'{tag}[{n}/{len(boards)}] {"SLOW" if slow else "OK  "} {uid}: {len(entry["tabs"])} shot(s)'
                      + (f', still loading: {", ".join(slow)}' if slow else ''), flush=True)
            except Exception as e:  # keep going: one broken board must not stop the gallery
                print(f'{tag}[{n}/{len(boards)}] FAIL {uid}: {str(e).splitlines()[0][:160]}', flush=True)
            entries.append(entry)
        browser.close()
    return entries


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--uids', default='')
    ap.add_argument('--width', type=int, default=1600)
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--jobs', type=int, default=1, help='browsers rendering in parallel')
    ap.add_argument('--show-logs', action='store_true', help='do not mask the log lines (private use)')
    a = ap.parse_args()
    url = os.environ.get('SHOTS_GRAFANA_URL', 'https://grafana.monlab.newt.cz').rstrip('/')
    token = os.environ['SHOTS_GRAFANA_TOKEN']
    boards = wanted_boards(url, token, set(filter(None, a.uids.split(','))))
    if a.limit:
        boards = boards[:a.limit]
    os.makedirs(a.out, exist_ok=True)
    manifest = {'grafana': url, 'rendered': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%MZ'), 'logsMasked': not a.show_logs, 'boards': []}
    jobs = max(1, min(a.jobs, len(boards)))
    if jobs == 1:
        manifest['boards'] = render(a.out, url, token, a.width, not a.show_logs, boards)
    else:
        with multiprocessing.Pool(jobs) as pool:
            parts = pool.starmap(render, [(a.out, url, token, a.width, not a.show_logs, boards[k::jobs], k, jobs) for k in range(jobs)])
        order = {b['uid']: i for i, b in enumerate(boards)}
        manifest['boards'] = sorted((e for part in parts for e in part), key=lambda e: order[e['uid']])
    with open(os.path.join(a.out, 'manifest.json'), 'w') as f:
        json.dump(manifest, f, indent=1)
    shots = sum(len(b['tabs']) for b in manifest['boards'])
    print(f'{len(manifest["boards"])} boards, {shots} shots -> {a.out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
