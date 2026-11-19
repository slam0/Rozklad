import json, os, subprocess, sys, tempfile, unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build_pobierz.py")


class T(unittest.TestCase):
    def test_empty(self):
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, "src"))
            subprocess.run([sys.executable, SCRIPT, os.path.join(d, "src"), os.path.join(d, "out"), "https://x/cydia"], check=True)
            self.assertFalse(os.path.exists(os.path.join(d, "out", "pobierz.json")))

    def test_files(self):
        with tempfile.TemporaryDirectory() as d:
            root = os.path.join(d, "pkg", "DEBIAN")
            os.makedirs(root)
            open(os.path.join(root, "control"), "w").write(
                "Package: a.b\nVersion: 2.0\nArchitecture: iphoneos-arm\nDescription: t\nMaintainer: m\n")
            os.makedirs(os.path.join(d, "src"))
            subprocess.run(["dpkg-deb", "-b", os.path.join(d, "pkg"), os.path.join(d, "src", "a.deb")], check=True, capture_output=True)
            open(os.path.join(d, "src", "Rozklad.ipa"), "wb").write(b"zip")
            out = os.path.join(d, "out")
            subprocess.run([sys.executable, SCRIPT, os.path.join(d, "src"), out, "https://x.github.io/cydia"], check=True)
            info = json.load(open(os.path.join(out, "pobierz.json")))
            self.assertEqual(info["version"], "2.0")
            self.assertTrue(info["ipa"])
            self.assertEqual(info["repo"], "https://x.github.io/cydia/")
            self.assertTrue(os.path.exists(os.path.join(out, "pobierz", "Rozklad.ipa")))
            self.assertTrue(os.path.exists(os.path.join(out, "pobierz", "Rozklad.deb")))


if __name__ == "__main__":
    unittest.main()
