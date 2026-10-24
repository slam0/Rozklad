import bz2, gzip, json, os, subprocess, sys, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "build_repo.py")


def make_deb(folder, version):
    root = os.path.join(folder, "pkg")
    os.makedirs(os.path.join(root, "DEBIAN"), exist_ok=True)
    with open(os.path.join(root, "DEBIAN", "control"), "w", encoding="utf-8") as f:
        f.write("Package: com.example.rozklad\nName: Rozkład\nVersion: %s\nArchitecture: iphoneos-arm\n"
                "Description: test\nMaintainer: t\nSection: Utilities\n" % version)
    os.makedirs(os.path.join(root, "x"), exist_ok=True)
    open(os.path.join(root, "x", "a"), "w").write("a")
    deb = os.path.join(folder, "src", "com.example.rozklad_%s_iphoneos-arm.deb" % version)
    os.makedirs(os.path.dirname(deb), exist_ok=True)
    subprocess.run(["dpkg-deb", "-b", root, deb], check=True, capture_output=True)
    return deb


class RepoTest(unittest.TestCase):
    def test_empty(self):
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, "src"))
            r = subprocess.run([sys.executable, SCRIPT, os.path.join(d, "src"), os.path.join(d, "out"), "https://x.github.io/R/"])
            self.assertEqual(r.returncode, 0)
            self.assertFalse(os.path.exists(os.path.join(d, "out", "pobierz.json")))

    def test_repo(self):
        with tempfile.TemporaryDirectory() as d:
            make_deb(d, "1.1.0")
            open(os.path.join(d, "src", "Rozklad.ipa"), "wb").write(b"zip")
            out = os.path.join(d, "out")
            subprocess.run([sys.executable, SCRIPT, os.path.join(d, "src"), out, "https://x.github.io/R"], check=True)
            pk = open(os.path.join(out, "repo", "Packages"), encoding="utf-8").read()
            self.assertIn("Package: com.example.rozklad", pk)
            self.assertIn("Filename: debs/com.example.rozklad_1.1.0_iphoneos-arm.deb", pk)
            self.assertIn("Icon: https://x.github.io/R/icon.png", pk)
            self.assertIn("SHA256: ", pk)
            self.assertEqual(gzip.open(os.path.join(out, "repo", "Packages.gz")).read().decode(), pk)
            self.assertEqual(bz2.open(os.path.join(out, "repo", "Packages.bz2")).read().decode(), pk)
            self.assertIn("Architectures: iphoneos-arm", open(os.path.join(out, "repo", "Release"), encoding="utf-8").read())
            info = json.load(open(os.path.join(out, "pobierz.json"), encoding="utf-8"))
            self.assertEqual(info["version"], "1.1.0")
            self.assertTrue(info["ipa"])
            self.assertEqual(info["repo"], "https://x.github.io/R/repo/")
            self.assertTrue(os.path.exists(os.path.join(out, "pobierz", "Rozklad.deb")))
            self.assertTrue(os.path.exists(os.path.join(out, "pobierz", "Rozklad.ipa")))
            # Size w Packages zgadza się z plikiem
            sz = os.path.getsize(os.path.join(out, "repo", "debs", "com.example.rozklad_1.1.0_iphoneos-arm.deb"))
            self.assertIn("Size: %d\n" % sz, pk)


if __name__ == "__main__":
    unittest.main()
