#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Dzieli duży plik GTFS (warsaw.zip) na małe pliki, które telefon może pobrać
pojedynczo ze strony na GitHub Pages:

  index.json              lista przystanków (do wyszukiwania na stronie)
  d/<v>/svc.json          kalendarze kursowania (wspólne dla wszystkich słupków)
  d/<v>/s/<numer>.json    odjazdy z jednego słupka

Użycie:  python3 build_data.py warsaw.zip katalog_wyjsciowy
Format plików jest opisany w README (sekcja "Strona z danymi").
"""
import csv
import io
import json
import os
import shutil
import sys
import unicodedata
import zipfile
from array import array
from datetime import datetime, timezone

KB = {'b': 1, 't': 2, 'p': 4, 'm': 8}
DAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']


def kind(route_type):
    """route_type z GTFS -> b/t/p/m (tak samo jak w generatorze)."""
    try:
        v = int(route_type)
    except (TypeError, ValueError):
        return 'b'
    if v == 1 or v in (401, 402):
        return 'm'
    if v == 0 or 900 <= v < 1000:
        return 't'
    if v == 2 or 100 <= v < 200 or 300 <= v < 400:
        return 'p'
    return 'b'


def norm(s):
    s = s.lower().replace('ł', 'l')
    s = unicodedata.normalize('NFD', s)
    return ''.join(c for c in s if not unicodedata.combining(c))


def is6(sid):
    return len(sid) == 6 and sid.isdigit()


def pole_code(stop_id, stop_code):
    if stop_code:
        return stop_code
    return stop_id[4:] if is6(stop_id) else stop_id


def rows(z, name):
    """Czyta plik CSV z zipa i zwraca (słownik nazw kolumn, iterator wierszy)."""
    try:
        raw = z.open(name)
    except KeyError:
        return None, iter(())
    rd = csv.reader(io.TextIOWrapper(raw, encoding='utf-8-sig', newline=''))
    try:
        head = next(rd)
    except StopIteration:
        return {}, iter(())
    return {h.strip(): i for i, h in enumerate(head)}, rd


def minutes(t):
    if not t:
        return None
    p = t.strip().split(':')
    try:
        return int(p[0]) * 60 + int(p[1])
    except (ValueError, IndexError):
        return None


def build(zip_path, out_dir, now=None, log=print):
    now = now or datetime.now(timezone.utc)
    version = now.strftime('%Y%m%d%H%M')
    z = zipfile.ZipFile(zip_path)

    # --- przystanki -> grupy (nazwa + pierwsze 4 cyfry numeru) -------------
    groups = {}      # klucz -> grupa
    order = []
    pole_of = {}     # stop_id -> słupek
    H, rd = rows(z, 'stops.txt')
    for x in rd:
        if not x:
            continue
        sid = x[H['stop_id']].strip()
        nm = x[H['stop_name']].strip()
        if not sid or not nm:
            continue
        gk = nm + '|' + sid[:4] if is6(sid) else nm
        g = groups.get(gk)
        if g is None:
            g = groups[gk] = {'n': nm, 'lat': x[H['stop_lat']].strip() if 'stop_lat' in H else '',
                              'lon': x[H['stop_lon']].strip() if 'stop_lon' in H else '', 'poles': []}
            order.append(g)
        code = x[H['stop_code']].strip() if 'stop_code' in H and H['stop_code'] < len(x) else ''
        p = {'id': sid, 'c': pole_code(sid, code), 'm': 0, 'data': {}}
        g['poles'].append(p)
        pole_of[sid] = p
    if not order:
        raise SystemExit('W pliku nie ma przystanków (stops.txt) - to na pewno GTFS?')
    log('przystanki: %d grup, %d słupków' % (len(order), len(pole_of)))

    # --- trasy, kursy ------------------------------------------------------
    H, rd = rows(z, 'routes.txt')
    route = {}
    for x in rd:
        if not x:
            continue
        rid = x[H['route_id']]
        short = x[H['route_short_name']] if 'route_short_name' in H else ''
        route[rid] = (short or rid, kind(x[H['route_type']]))

    services = []        # lista kalendarzy
    sidx = {}
    tg_list = []         # (linia, kierunek, numer kalendarza, rodzaj)
    tg_idx = {}
    trip_tg = {}
    H, rd = rows(z, 'trips.txt')
    for x in rd:
        if not x:
            continue
        r = route.get(x[H['route_id']])
        if r is None:
            continue
        sv = x[H['service_id']]
        if sv not in sidx:
            sidx[sv] = len(services)
            services.append({'d': [0] * 7, 's': '', 'e': '', 'a': [], 'r': []})
        head = x[H['trip_headsign']] if 'trip_headsign' in H else ''
        key = (r[0], head, sidx[sv], r[1])
        i = tg_idx.get(key)
        if i is None:
            i = tg_idx[key] = len(tg_list)
            tg_list.append(key)
        trip_tg[x[H['trip_id']]] = i
    log('kursy: %d, odmian: %d, kalendarzy: %d' % (len(trip_tg), len(tg_list), len(services)))

    # --- kalendarze --------------------------------------------------------
    end = ''
    H, rd = rows(z, 'calendar.txt')
    for x in rd:
        if not x:
            continue
        k = sidx.get(x[H['service_id']])
        if k is None:
            continue
        s = services[k]
        s['d'] = [int(x[H[d]]) for d in DAYS]
        s['s'] = x[H['start_date']]
        s['e'] = x[H['end_date']]
        if s['e'] > end:
            end = s['e']
    H, rd = rows(z, 'calendar_dates.txt')
    for x in rd:
        if not x:
            continue
        k = sidx.get(x[H['service_id']])
        if k is None:
            continue
        d = x[H['date']]
        add = x[H['exception_type']] == '1'
        services[k]['a' if add else 'r'].append(d)
        if add and d > end:
            end = d

    # --- godziny odjazdów --------------------------------------------------
    H, rd = rows(z, 'stop_times.txt')
    it, is_, dt, at = H['trip_id'], H['stop_id'], H.get('departure_time'), H.get('arrival_time')
    n = 0
    for x in rd:
        pole = pole_of.get(x[is_])
        if pole is None:
            continue
        tg = trip_tg.get(x[it])
        if tg is None:
            continue
        m = minutes(x[dt]) if dt is not None else None
        if m is None and at is not None:
            m = minutes(x[at])
        if m is None:
            continue
        arr = pole['data'].get(tg)
        if arr is None:
            arr = pole['data'][tg] = array('i')
        arr.append(m)
        pole['m'] |= KB[tg_list[tg][3]]
        n += 1
    log('odjazdów: %d' % n)

    # --- zapis -------------------------------------------------------------
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    ddir = os.path.join(out_dir, 'd', version)
    sdir = os.path.join(ddir, 's')
    os.makedirs(sdir)

    def dump(path, obj):
        with open(path, 'w', encoding='ascii') as f:
            json.dump(obj, f, ensure_ascii=True, separators=(',', ':'))

    gen = now.strftime('%Y-%m-%d')
    dump(os.path.join(ddir, 'svc.json'), {'gen': gen, 'end': end, 'svc': services})

    index = []
    num = 0
    order = [g for g in order if any(p['m'] for p in g['poles'])]
    order.sort(key=lambda g: (norm(g['n']), g['n']))
    for g in order:
        poles = []
        gm = 0
        for p in sorted(g['poles'], key=lambda p: p['c']):
            if not p['m']:
                continue
            groups_out = []
            for tg in sorted(p['data'], key=lambda t: (tg_list[t][3], tg_list[t][0], tg_list[t][1], tg_list[t][2])):
                line, head, sv, kd = tg_list[tg]
                groups_out.append([line, head, sv, kd, sorted(set(p['data'][tg]))])
            dump(os.path.join(sdir, '%d.json' % num), {'n': g['n'], 'c': p['c'], 'g': groups_out})
            poles.append([num, p['c'], p['m']])
            gm |= p['m']
            num += 1
        k = norm(g['n'])
        index.append([g['n'], '' if k == g['n'].lower() else k, gm, g['lat'][:8], g['lon'][:8], poles])
    dump(os.path.join(out_dir, 'index.json'), {'v': version, 'gen': gen, 'end': end, 'g': index})
    log('zapisano: %d przystanków, %d słupków, wersja %s' % (len(index), num, version))
    return version


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit('Użycie: build_data.py warsaw.zip katalog_wyjsciowy')
    build(sys.argv[1], sys.argv[2])
