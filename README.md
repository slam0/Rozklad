# Waluty – przelicznik walut na iOS 6

Przelicznik walut z **aktualnymi kursami z internetu**, napisany w Objective-C pod iOS 6 (jailbreak), budowany w Theosie na GitHubie.
Wygląd taki sam jak w aplikacji Gym: grafit z połyskiem, 6 motywów kolorystycznych (domyślnie Zieleń), 3 języki (polski, English, Русский).
Kursy zapisują się w telefonie, więc przelicznik działa też bez internetu (na ostatnich pobranych kursach).

## Co potrafi (1.0.2)

* **Przelicznik** – wpisujesz kwotę, wybierasz dwie waluty, wynik liczy się od razu. Przycisk ⇅ zamienia waluty miejscami, dotknięcie wyniku kopiuje go do schowka.
  Pod spodem lista tej samej kwoty we wszystkich **ulubionych** walutach (dotknięcie waluty ustawia ją jako docelową).
  Widać kurs (`1 PLN = 0,2326 EUR`), datę kursów i źródło. Gdy kursy mają 3 dni lub więcej, pojawia się ostrzeżenie.
* **Kursy** – wszystkie waluty względem wybranej waluty bazowej (przycisk w lewym górnym rogu), w obie strony (`1 EUR = 4,3000 PLN`),
  wyszukiwarka po kodzie i po nazwie (w każdym z trzech języków), gwiazdka dodaje walutę do ulubionych, dotknięcie waluty otwiera przelicznik.
* **Ustawienia** – język, motyw, **źródło kursów** (automatycznie / open.er-api.com / NBP), ręczne odświeżanie, przywrócenie domyślnych ulubionych,
  usunięcie danych. Język i motyw zmieniają się od razu, bez restartu.
* Nazwy ok. 150 walut po polsku, angielsku i rosyjsku (`WLCurrencies.m`).

## Skąd kursy

| Źródło | Adres | Uwagi |
|---|---|---|
| **open.er-api.com** (główne) | `https://open.er-api.com/v6/latest/PLN` | ok. 160 walut, aktualizacja raz na dobę, darmowe bez klucza. Wymaga odnośnika do `exchangerate-api.com` (jest w Ustawieniach i pod listą Kursów). |
| **NBP** (zapasowe) | `https://api.nbp.pl/api/exchangerates/tables/A/?format=json` | tabela A kursów średnich, ok. 33 waluty, dni robocze. |

W trybie *Automatycznie* aplikacja próbuje kolejno: ER-API przez HTTPS → NBP przez HTTPS → ER-API przez HTTP → NBP przez HTTP i bierze pierwszą odpowiedź, którą umie przeczytać.
Kursy pobierają się po uruchomieniu i po powrocie do aplikacji, jeśli ostatnie mają ponad godzinę (nie częściej niż co 2 minuty, żeby nie męczyć serwera;
ręczne „Odśwież” najwyżej raz na minutę). Serwer ER-API na chwilę blokuje adresy, które pytają zbyt często, dlatego jest ten limit.
Kursy są **orientacyjne** (nie służą do rozliczeń, kantory i banki mają własne).

### HTTPS na iOS 6

Stary iOS 6 nie obsługuje nowoczesnego TLS, którego wymagają te serwery. Żeby pobieranie działało, zainstaluj w Cydii poprawkę SSL/TLS (tę samą, której wymaga Rozkład).
Bez niej aplikacja pokaże komunikat „Nie udało się połączyć bezpiecznie (HTTPS)”, ale nadal działa na zapisanych kursach, jeśli już kiedyś się pobrały.

## Jak liczy

Każdy kurs jest w tabeli zapisany jako „ile sztuk waluty dostajesz za 1 PLN”. Z NBP to `1 / kurs średni`, z ER-API kurs podzielony przez kurs złotego
(dzięki temu nie ma znaczenia, jaka waluta była bazowa u dostawcy). Przeliczenie: `kwota × kurs(docelowa) / kurs(źródłowa)`, więc dowolna para walut idzie „przez złotego”.
Cała ta logika (czytanie JSON, liczenie, zapis kursów, formatowanie kwot, daty, odmiana) jest w `wl_core.c` w czystym C, bez bibliotek, i ma **815 testów** (`tests/core_test.c`).

## Diagnostyka

Aplikacja zapisuje w `Documents` ostatni wykonywany „krok” (`ostatni-krok.txt`) i treść nieobsłużonego błędu (`blad.txt`). Jeśli poprzednie uruchomienie
zakończyło się awarią, po następnym starcie pokaże okienko „Waluty – diagnostyka” z tą informacją – wystarczy zrobić zdjęcie ekranu. Pliki można też zobaczyć w iTunes → Udostępnianie plików.

## Budowanie

1. Wgraj całą zawartość tego folderu do nowego publicznego repozytorium **Waluty** na GitHubie (folder `.github` jest ukryty – w Finderze Cmd+Shift+.).
2. Settings → Actions → General → Workflow permissions → **Read and write permissions**.
3. Actions → **Zbuduj aplikację** → Run workflow (nie „Re-run all jobs”). Powstają `Waluty.ipa` i `.deb`, które trafiają do wydania `najnowsza`.
4. Żeby aplikacja była w Cydii: dopisz `slam0/Waluty` do pliku `projekty.txt` w repozytorium `cydia` i wgraj `Resources/Icon@2x.png` jako `site/icons/waluty.png` (adres ikony jest w pliku `control`).

Lokalnie: `./build.sh` (potrzebny Theos), testy logiki: `gcc -Wall wl_core.c tests/core_test.c -lm && ./a.out`.
Ikona i ekrany startowe powstają ze skryptu `python3 tools/make_images.py` (Pillow).

## Pliki

| Plik | Rola |
|---|---|
| `wl_core.*` | czysta logika w C: czytanie odpowiedzi ER-API i NBP, tabela kursów, przeliczanie, zapis/odczyt pamięci podręcznej, parsowanie i formatowanie kwot, daty, odmiana |
| `wl_libc.c` | własne `memcpy`/`memset`… (zastępcze pliki SDK z GitHuba ich nie mają) |
| `WLRates.*` | pobieranie kursów (`NSURLConnection`), kolejność źródeł, obsługa błędów, plik `Documents/kursy.txt` |
| `WLStore.*` | ustawienia i stan w `Documents/waluty.json`: język, motyw, źródło, ostatnie waluty i kwota, ulubione |
| `WLCurrencies.*` | nazwy walut PL/EN/RU |
| `WLConverterController.*`, `WLRatesController.*`, `WLPickerController.*`, `WLSettingsController.*` | ekrany |
| `WLLang.*` | języki: tabela tłumaczeń `GL(@"polski napis")` (EN/RU) |
| `WLTheme.*`, `WLViews.*` | wygląd: motywy i paleta, paski, żelowe przyciski, komórki, ikonki, formatowanie liczb |

## Uwaga o budowaniu (ważne przy zmianach w kodzie)

Zastępcze pliki SDK z GitHuba przypisują niektóre klasy do złych bibliotek (np. `NSHTTPURLResponse`, `NSURLConnection`, `NSMutableURLRequest` do CFNetwork),
a na iOS 6 ich tam nie ma. Odwołanie do takiej klasy w kodzie kończy się błędem dyld „Symbol not found” i zamknięciem aplikacji od razu po starcie.
Dlatego kod sieciowy (`WLRates.m`, `WLOpenURL` w `WLViews.m`) szuka tych klas po nazwie przez `NSClassFromString`. Nowych klas z innych bibliotek niż UIKit/Foundation
nie dodawaj bez sprawdzenia.

## Dodawanie języka, motywu albo waluty

* Napisy w kodzie są po polsku i opakowane w `GL(@"…")`; tłumaczenie to jeden wiersz `{ PL, EN, RU }` w `WLLang.m`. Brak wiersza = napis zostaje po polsku.
* Motyw to jeden wiersz w tabeli `kThemes` w `WLTheme.m`.
* Nazwa waluty to jeden wiersz w `WLCurrencies.m`. Waluta, której tam nie ma, nadal działa (pokazuje sam kod).

## Źródła i licencje

Kursy: [open.er-api.com](https://www.exchangerate-api.com) („Rates By Exchange Rate API”) oraz Narodowy Bank Polski ([nbp.pl](https://nbp.pl)).
Aplikacja nie wysyła do nikogo żadnych danych o użytkowniku; jedyne zapytania to pobranie tabeli kursów.
