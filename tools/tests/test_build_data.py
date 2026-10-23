# -*- coding: utf-8 -*-
"""Porównuje wynik build_data.py z niezależną, prostą implementacją tego,
co robił dotychczasowy generator (jeden duży rozklad.json)."""
import csv, io, json, os, subprocess, sys, tempfile, zipfile, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import build_data, fake_gtfs

KB = build_data.KB


def reference(zip_path, wanted):
    """wanted: {stop_id: maska rodzajów}. Zwraca {(nazwa, kod): posortowane odjazdy [linia,kierunek,kalendarz(opis),minuta,rodzaj]}"""
    z = zipfile.ZipFile(zip_path)
    def rd(n):
        r = csv.DictReader(io.TextIOWrapper(z.open(n), encoding='utf-8-sig', newline=''))
        return list(r)
    stops = {r['stop_id']: r for r in rd('stops.txt')}
    routes = {r['route_id']: r for r in rd('routes.txt')}
    trips = {r['trip_id']: r for r in rd('trips.txt')}
    cal = {r['service_id']: r for r in rd('calendar.txt')}
    res = {}
    for r in rd('stop_times.txt'):
        sid = r['stop_id']
        if sid not in wanted:
            continue
        t = trips[r['trip_id']]
        rt = routes[t['route_id']]
        kd = build_data.kind(rt['route_type'])
        if not wanted[sid] & KB[kd]:
            continue
        h, m = r['departure_time'].split(':')[:2]
        s = stops[sid]
        code = s['stop_code'] or (sid[4:] if len(sid) == 6 and sid.isdigit() else sid)
        res.setdefault((s['stop_name'], code), set()).add(
            (rt['route_short_name'], t['trip_headsign'], t['service_id'], int(h) * 60 + int(m), kd))
    return {k: sorted(v, key=lambda d: (d[3], d)) for k, v in res.items()}


def assemble(base, v, pole_masks):
    """To samo robi strona (ES5) i aplikacja: składa rozklad.json z małych plików."""
    with open(os.path.join(base, 'd', v, 'svc.json')) as f:
        svc = json.load(f)
    remap, S, stops = {}, [], []
    for num, mask in pole_masks:
        with open(os.path.join(base, 'd', v, 's', '%d.json' % num)) as f:
            p = json.load(f)
        d = []
        for line, head, sv, kd, mins in p['g']:
            if not mask & KB[kd]:
                continue
            if sv not in remap:
                remap[sv] = len(S)
                S.append(svc['svc'][sv])
            for m in mins:
                d.append([line, head, remap[sv], m, kd])
        d.sort(key=lambda x: x[3])
        if d:
            stops.append({'n': p['n'], 'c': p['c'], 'd': d})
    return {'gen': svc['gen'], 'end': svc['end'], 'stops': stops, 'svc': S}


class T(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.zip = os.path.join(cls.tmp, 'w.zip')
        fake_gtfs.make(cls.zip)
        cls.out = os.path.join(cls.tmp, 'site')
        cls.v = build_data.build(cls.zip, cls.out, log=lambda *_: None)
        with open(os.path.join(cls.out, 'index.json')) as f:
            cls.idx = json.load(f)

    def test_index(self):
        idx = self.idx
        names = [g[0] for g in idx['g']]
        self.assertEqual(idx['v'], self.v)
        self.assertNotIn('Pętla Bez Kursów', names)           # bez kursów -> pominięta
        self.assertEqual(names, sorted(names, key=lambda n: (build_data.norm(n), n)))
        g = {x[0]: x for x in idx['g']}
        self.assertEqual(g['Centrum'][2], 3)                     # autobus + tramwaj (słupek 03)
        self.assertEqual(g['Metro Wilanowska'][2], 8)
        self.assertEqual(g['Świętokrzyska'][1], 'swietokrzyska')  # klucz do szukania bez ogonków
        self.assertEqual(g['Centrum'][1], '')                    # brak klucza, gdy taki sam jak nazwa małymi
        self.assertEqual([p[1] for p in g['Centrum'][5]], ['01', '02', '03'])
        self.assertEqual([p[1] for p in g['Warszawa Zachodnia'][5]], ['A1'])
        self.assertEqual(g['Pl. "Wilsona", Żoliborz'][2], 1 | 0)  # 175, 222 i N31/702 autobusowe

    def test_ascii_only(self):
        for root, _, files in os.walk(self.out):
            for f in files:
                with open(os.path.join(root, f), 'rb') as fh:
                    fh.read().decode('ascii')

    def test_equals_reference_all_poles(self):
        pole_masks, wanted = [], {}
        id_by = {}
        for r in csv.DictReader(io.TextIOWrapper(zipfile.ZipFile(self.zip).open('stops.txt'), encoding='utf-8-sig', newline='')):
            id_by[(r['stop_name'], r['stop_code'] or (r['stop_id'][4:] if len(r['stop_id']) == 6 and r['stop_id'].isdigit() else r['stop_id']))] = r['stop_id']
        for g in self.idx['g']:
            for num, code, mask in g[5]:
                pole_masks.append((num, mask))
                wanted[id_by[(g[0], code)]] = mask
        got = assemble(self.out, self.v, pole_masks)
        ref = reference(self.zip, wanted)
        svc = got['svc']
        # sprowadź kalendarz do postaci opisowej, żeby porównać z referencją
        cal = {}
        for r in csv.DictReader(io.TextIOWrapper(zipfile.ZipFile(self.zip).open('calendar.txt'), encoding='utf-8-sig', newline='')):
            cal[r['service_id']] = [int(r[d]) for d in build_data.DAYS] + [r['start_date'], r['end_date']]
        name = {}
        for sid, c in cal.items():
            name[(tuple(c[:7]), c[7], c[8])] = sid
        name[((0,) * 7, '', '')] = 'HOL'
        mine = {}
        for s in got['stops']:
            key = (s['n'], s['c'])
            mine[key] = sorted(((l, h, name[(tuple(svc[sv]['d']), svc[sv]['s'], svc[sv]['e'])], m, k) for l, h, sv, m, k in s['d']),
                               key=lambda d: (d[3], d))
        self.assertEqual(set(mine), set(ref))
        for k in ref:
            self.assertEqual(mine[k], ref[k], k)
        self.assertEqual(got['end'], '20261231')
        self.assertTrue(any(m > 1440 for s in got['stops'] for _, _, _, m, _ in s['d']))  # godziny po 24:00

    def test_kind_mask_filters(self):
        g = {x[0]: x for x in self.idx['g']}
        num = g['Pl. "Wilsona", Żoliborz'][5][0][0]
        a = assemble(self.out, self.v, [(num, 1)])
        b = assemble(self.out, self.v, [(num, 2)])
        self.assertTrue(a['stops'] and not b['stops'])

    def test_services_remap_only_used(self):
        g = {x[0]: x for x in self.idx['g']}
        num = g['Metro Wilanowska'][5][0][0]
        a = assemble(self.out, self.v, [(num, 8)])
        self.assertEqual(len(a['svc']), 3)
        for s in a['stops']:
            for d in s['d']:
                self.assertLess(d[2], len(a['svc']))


if __name__ == '__main__':
    unittest.main()
