# -*- coding: utf-8 -*-
"""Tworzy sztuczny, ale podchwytliwy plik GTFS do testów."""
import io, random, sys, zipfile


def make(path, seed=1, trips_per_route=40):
    rnd = random.Random(seed)
    stops = [
        # id, kod, nazwa
        ('700101', '01', 'Centrum'), ('700102', '02', 'Centrum'), ('700103', '', 'Centrum'),
        ('700201', '01', 'Rakowska'), ('700202', '02', 'Rakowska'),
        ('300101', '01', 'Świętokrzyska'), ('300102', '02', 'Świętokrzyska'),
        ('400101', '01', 'Dw. Centralny'), ('400102', '02', 'Dw. Centralny'),
        ('500101', '01', 'Pl. "Wilsona", Żoliborz'),
        ('600101', '01', 'Metro Wilanowska'), ('600102', '02', 'Metro Wilanowska'),
        ('A1', '', 'Warszawa Zachodnia'),
        ('999901', '01', 'Pętla Bez Kursów'),
    ]
    routes = [
        ('R175', '175', 3), ('R222', '222', 3), ('R17', '17', 0), ('RM1', 'M1', 1),
        ('RS1', 'S1', 2), ('RN3', 'N31', 3), ('R702', '702', 702),
    ]
    paths = {
        'R175': ['700101', '700201', '500101'], 'R222': ['700102', '700202', '500101'],
        'R17': ['300101', '300102', '700103'], 'RM1': ['600101', '600102'],
        'RS1': ['400101', 'A1', '400102'], 'RN3': ['700101', '700202'], 'R702': ['500101', '700101'],
    }
    out = {}
    s = io.StringIO(newline='')
    s.write('﻿stop_id,stop_code,stop_name,stop_lat,stop_lon\r\n')
    for i, c, n in stops:
        s.write('%s,%s,"%s",52.2%s,21.0%s\r\n' % (i, c, n.replace('"', '""'), rnd.randint(100, 999), rnd.randint(100, 999)))
    out['stops.txt'] = s.getvalue()
    out['routes.txt'] = 'route_id,route_short_name,route_type\n' + ''.join('%s,%s,%s\n' % r for r in routes)
    out['calendar.txt'] = ('service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\n'
                           'WK,1,1,1,1,1,0,0,20261001,20261231\nSA,0,0,0,0,0,1,0,20261001,20261215\n')
    out['calendar_dates.txt'] = ('service_id,date,exception_type\nWK,20261111,2\nSA,20261111,1\nHOL,20261224,1\nHOL,20261225,1\n')
    trips, st = [], []
    n = 0
    for rid, short, rt in routes:
        for k in range(trips_per_route):
            svc = ['WK', 'SA', 'HOL'][k % 3]
            n += 1
            tid = 'T%d' % n
            head = ['Lotnisko', 'Śmiełowska', 'Pętla, "Nowa"', ''][k % 4]
            trips.append((tid, rid, svc, head))
            base = 4 * 60 + k * 37 + (23 * 60 if k % 17 == 0 else 0)
            for j, sid in enumerate(paths[rid]):
                t = base + j * 4
                hh, mm = divmod(t, 60)
                st.append('%s,%s:%02d:00,%s:%02d:00,%s,%d\n' % (tid, '%02d' % hh, mm, '%02d' % hh, mm, sid, j))
    out['trips.txt'] = 'route_id,service_id,trip_id,trip_headsign\n' + ''.join('%s,%s,%s,"%s"\n' % (r, s_, t, h.replace('"', '""')) for t, r, s_, h in trips)
    out['stop_times.txt'] = 'trip_id,arrival_time,departure_time,stop_id,stop_sequence\n' + ''.join(st)
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        for k, v in out.items():
            z.writestr(k, v.encode('utf-8'))


if __name__ == '__main__':
    make(sys.argv[1])
