#!/usr/bin/env python3
"""Składa część strony do pobierania aplikacji.

Użycie:  python3 tools/build_repo.py <folder_z_plikami> <folder_strony> <adres_strony>

<folder_z_plikami> - tu leżą pobrane z Release pliki *.deb (i opcjonalnie *.ipa).
Skrypt tworzy w <folder_strony>:
  pobierz.json            - informacje o wersji (czyta je strona główna)
  pobierz/Rozklad.deb     - stały adres pliku do pobrania w Safari
  pobierz/Rozklad.ipa     - (jeśli jest) wersja dla komputera
  repo/                   - repozytorium APT dla Cydii (Packages, Packages.gz, Packages.bz2, Release)
Gdy nie ma żadnego pliku .deb, nic nie tworzy i kończy się bez błędu.
"""
import bz2, glob, gzip, hashlib, json, os, shutil, subprocess, sys, time


def control_of(deb):
    out = subprocess.run(["dpkg-deb", "-f", deb], check=True, capture_output=True).stdout
    return out.decode("utf-8").rstrip("\n")


def field(ctrl, name):
    for line in ctrl.split("\n"):
        if line.startswith(name + ":"):
            return line.split(":", 1)[1].strip()
    return ""


def digests(path):
    h = {k: hashlib.new(k) for k in ("md5", "sha1", "sha256")}
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            for v in h.values():
                v.update(chunk)
    return {k: v.hexdigest() for k, v in h.items()}


def main(src, out, site):
    debs = sorted(glob.glob(os.path.join(src, "*.deb")))
    if not debs:
        print("Brak plików .deb - strona będzie bez pobierania aplikacji.")
        return 0
    if not site.endswith("/"):
        site += "/"
    repo = os.path.join(out, "repo")
    os.makedirs(os.path.join(repo, "debs"), exist_ok=True)
    os.makedirs(os.path.join(out, "pobierz"), exist_ok=True)

    blocks = []
    info = None
    for deb in debs:
        ctrl = control_of(deb)
        name = os.path.basename(deb)
        shutil.copy(deb, os.path.join(repo, "debs", name))
        d = digests(deb)
        block = ctrl + "\n"
        block += "Filename: debs/%s\nSize: %d\nMD5sum: %s\nSHA1: %s\nSHA256: %s\n" % (
            name, os.path.getsize(deb), d["md5"], d["sha1"], d["sha256"])
        if not field(ctrl, "Icon"):
            block += "Icon: %sicon.png\n" % site
        if not field(ctrl, "Homepage"):
            block += "Homepage: %s\n" % site
        blocks.append(block)
        info = {"version": field(ctrl, "Version"), "package": field(ctrl, "Package"),
                "size": os.path.getsize(deb)}

    packages = ("\n".join(blocks)).encode("utf-8")
    with open(os.path.join(repo, "Packages"), "wb") as f:
        f.write(packages)
    with gzip.open(os.path.join(repo, "Packages.gz"), "wb", 9) as f:
        f.write(packages)
    with open(os.path.join(repo, "Packages.bz2"), "wb") as f:
        f.write(bz2.compress(packages, 9))
    release = ("Origin: Rozkład\nLabel: Rozkład\nSuite: stable\nVersion: 1.0\nCodename: ios\n"
               "Architectures: iphoneos-arm\nComponents: main\n"
               "Description: Rozkład - offline timetable for iOS 6 (autobus, tramwaj, pociąg, metro)\n")
    with open(os.path.join(repo, "Release"), "w", encoding="utf-8") as f:
        f.write(release)
    with open(os.path.join(repo, "index.html"), "w", encoding="utf-8") as f:
        f.write('<!doctype html><meta charset="utf-8"><title>Rozkład – repo</title>'
                '<p>To jest repozytorium Cydii. Dodaj adres <b>%srepo/</b> w Cydii (Manage → Sources → Edit → Add).'
                '<p><a href="%s">← Strona główna</a>' % (site, site))

    # stały adres pliku do pobrania = najwyższa wersja (ostatni w posortowanej liście)
    shutil.copy(debs[-1], os.path.join(out, "pobierz", "Rozklad.deb"))
    ipas = sorted(glob.glob(os.path.join(src, "*.ipa")))
    info["ipa"] = False
    if ipas:
        shutil.copy(ipas[-1], os.path.join(out, "pobierz", "Rozklad.ipa"))
        info["ipa"] = True
        info["ipa_size"] = os.path.getsize(ipas[-1])
    info["date"] = time.strftime("%Y-%m-%d", time.gmtime())
    info["repo"] = site + "repo/"
    with open(os.path.join(out, "pobierz.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False)
    print("Repozytorium Cydii:", info)
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(*sys.argv[1:]))
