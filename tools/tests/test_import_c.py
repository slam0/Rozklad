# -*- coding: utf-8 -*-
"""Składanie rozklad.json w C (rz_import.c) kontra implementacja wzorcowa w Pythonie,
plus odporność na uszkodzone / złośliwe pliki."""
import json, os, random, shutil, subprocess, sys, tempfile, unittest
sys.path.insert(0, os.path.dirname(__file__)); sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import build_data, fake_gtfs, test_build_data as T

APP = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))


class C(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.cli = os.path.join(cls.tmp, 'cli')
        subprocess.check_call(['gcc', '-std=c99', '-g', '-O1', '-Wall', '-o', cls.cli,
                               os.path.join(APP, 'tests', 'import_cli.c'), os.path.join(APP, 'rz_import.c')])
        cls.zip = os.path.join(cls.tmp, 'w.zip')
        fake_gtfs.make(cls.zip, trips_per_route=60)
        cls.site = os.path.join(cls.tmp, 'site')
        cls.v = build_data.build(cls.zip, cls.site, log=lambda *_: None)
        with open(os.path.join(cls.site, 'index.json')) as f:
            cls.idx = json.load(f)
        cls.poles = [(p[0], p[2]) for g in cls.idx['g'] for p in g[5]]

    def run_cli(self, pole_masks, site=None, wrap=None):
        arg = ','.join('%d.%d' % pm for pm in pole_masks)
        cmd = [self.cli, site or self.site, self.v, arg]
        if wrap:
            cmd = wrap + cmd
        return subprocess.run(cmd, capture_output=True)

    def test_matches_reference(self):
        rnd = random.Random(7)
        for trial in range(40):
            sel = rnd.sample(self.poles, rnd.randint(1, len(self.poles)))
            pm = [(n, rnd.choice([m, m, 15, 1, 2, 4, 8, 3]) if trial % 2 else m) for n, m in sel]
            r = self.run_cli(pm)
            self.assertEqual(r.returncode, 0, r.stderr)
            got = json.loads(r.stdout.decode('ascii'))
            exp = T.assemble(self.site, self.v, pm)
            self.assertEqual(got, exp, pm)

    @unittest.skipUnless(shutil.which('valgrind'), 'brak valgrinda')
    def test_valgrind_clean(self):
        r = self.run_cli(self.poles, wrap=['valgrind', '-q', '--error-exitcode=9', '--leak-check=full'])
        self.assertEqual(r.returncode, 0, r.stderr.decode())

    def test_robust_to_garbage(self):
        """Uszkodzone pliki dają błąd (kod 5/7), nigdy zawieszenia ani awarii."""
        rnd = random.Random(3)
        files = []
        for root, _, fs in os.walk(os.path.join(self.site, 'd')):
            files += [os.path.join(root, f) for f in fs]
        for trial in range(250):
            site = os.path.join(self.tmp, 'mut')
            shutil.rmtree(site, ignore_errors=True)
            shutil.copytree(self.site, site)
            victim = os.path.join(site, os.path.relpath(rnd.choice(files), self.site))
            with open(victim, 'rb') as f:
                data = bytearray(f.read())
            how = trial % 5
            if how == 0 and len(data) > 2:
                data = data[:rnd.randrange(1, len(data))]
            elif how == 1:
                for _ in range(rnd.randint(1, 6)):
                    data[rnd.randrange(len(data))] = rnd.randrange(256)
            elif how == 2:
                i = rnd.randrange(len(data)); data[i:i] = rnd.choice([b'[', b']', b'{', b'"', b',', b'\\', b'9999999999999999999'])
            elif how == 3:
                i = rnd.randrange(len(data)); del data[i:i + rnd.randint(1, 8)]
            else:
                data = bytearray(b'[' * 5000 + b']' * 5000)
            with open(victim, 'wb') as f:
                f.write(data)
            r = self.run_cli(self.poles, site=site, wrap=['valgrind', '-q', '--error-exitcode=9'] if (trial % 10 == 0 and shutil.which('valgrind')) else None)
            self.assertIn(r.returncode, (0, 5, 7), (trial, victim, r.returncode, r.stderr[-300:]))
            if r.returncode == 0:
                json.loads(r.stdout.decode('ascii'))      # jeśli przyjęto, wynik musi być poprawnym JSON-em

    def test_bad_references(self):
        # kalendarz spoza zakresu
        site = os.path.join(self.tmp, 'bad')
        shutil.rmtree(site, ignore_errors=True); shutil.copytree(self.site, site)
        p = os.path.join(site, 'd', self.v, 's', '0.json')
        with open(p) as f: d = json.load(f)
        d['g'][0][2] = 999
        with open(p, 'w') as f: json.dump(d, f)
        r = self.run_cli([(0, 1)], site=site)
        self.assertEqual(r.returncode, 7)
        self.assertIn('kalend', r.stderr.decode())
        # nieznany rodzaj
        d['g'][0][2] = 0; d['g'][0][3] = 'x'
        with open(p, 'w') as f: json.dump(d, f)
        self.assertEqual(self.run_cli([(0, 1)], site=site).returncode, 7)


if __name__ == '__main__':
    unittest.main()
