# Onboarding — vom ersten Kontakt bis zum laufenden SpielPlaner

> © Frank-Christian Struve 2026 · Lizenz: PolyForm Noncommercial 1.0.0

Diese Anleitung führt dich Schritt für Schritt durch die **Erstinstallation
des SpielPlaners** in deinem Theater. Sie ergänzt das [README](README.md)
um den Teil **vor** dem Klonen: Lizenz, Zugang zur GitHub Container
Registry (GHCR), Voraussetzungen.

---

## 1. Lizenz prüfen

Bevor du etwas installierst, klär für dich:

| Du bist… | Lizenz | Aktion |
|---|---|---|
| Gemeinnütziges Theater, Kulturverein, Stadt-/Staatstheater | **PolyForm Noncommercial 1.0.0** ([LICENSE](LICENSE)) | freier Zugang — Mail an Lizenzgeber genügt |
| Bildungseinrichtung, Hochschule, Schultheater | PolyForm Noncommercial 1.0.0 | freier Zugang |
| Forschungseinrichtung, Privatperson | PolyForm Noncommercial 1.0.0 | freier Zugang |
| Kommerzieller Veranstalter, kommerzielles Theaterunternehmen, SaaS-Anbieter | **separate kommerzielle Lizenz erforderlich** | Anfrage an Lizenzgeber, individueller Vertrag |

Bei Unsicherheit über die eigene Einordnung — einfach mitteilen, wir klären's.

---

## 2. Zugang anfragen

Schreib eine Mail an **hallo@feinfein.de** mit folgenden Angaben:

```
Betreff: SpielPlaner-Installation — Zugangsanfrage [Theater-Name]

Theater / Organisation: <Name>
Rechtsform:             <e.V., gGmbH, Eigenbetrieb, GmbH, ...>
Adresse:                <Strasse, PLZ, Ort>
Webseite:               <Adresse>
Ansprechperson:         <Name, Rolle, Mail-Adresse>
GitHub-Username:        <falls vorhanden — fuer Lizenz-Audit, optional>

Kurzer Kontext:
- Wie viele Mitarbeitende?
- Welche SpielPlaner-Module interessieren euch zuerst?
  (Spielplan/Personal, KartenPlaner, KuechenPlaner, ProbenPlaner, oeffentliche Website?)
- Geplanter Server (Synology / Linux / Mac mini)?
```

Wir antworten in der Regel innerhalb von **2 Werktagen** mit:
- Lizenz-Bestätigung (für Noncommercial: formfreie Mail-Bestätigung)
- **GHCR Read-Token (PAT)** zum Pullen der Container-Images
- Diese Anleitung als Erinnerung

> **Datenschutz:** Die übermittelten Daten dienen ausschließlich der
> Lizenz-Vereinbarung und werden nicht an Dritte weitergegeben.

---

## 3. Voraussetzungen am Server prüfen

Bevor du den Token nutzt, sollten folgende Komponenten am Zielserver
installiert sein:

| Komponente | Mindestversion | Pruefen mit |
|---|---|---|
| OS | macOS 13 / Linux Debian, Ubuntu, DSM 7.2 | `uname -a` |
| Docker | 24.0+ | `docker --version` |
| Docker Compose v2 | (im Docker enthalten) | `docker compose version` |
| RAM | 4 GB frei | `free -h` (Linux) oder Activity Monitor |
| Plattenplatz | 5 GB initial, +1 GB/Jahr Audit-Log | `df -h` |
| Open Ports | 3000 (Web), 8000 (API), opt. 3001 (WebPlaner), 80/443 (Traefik) | `lsof -i :3000` |

**Auf Synology DSM:** „Container Manager" aus dem Paket-Zentrum installiert,
SSH eingeschaltet, dein User in der `administrators`-Gruppe (für `sudo`).

**Auf Linux:** Dein User in der `docker`-Gruppe (`sudo usermod -aG docker $USER`,
dann ausloggen + neu einloggen). Sonst brauchst du `sudo` vor jedem Docker-Befehl.

**Auf macOS:** Docker Desktop installiert + gestartet.

---

## 4. Installer holen

```sh
git clone https://github.com/spielplaner/install.git spielplaner
cd spielplaner
```

Du hast jetzt:
- `compose.yml` — Container-Definition für alle Services
- `install.sh` — Interaktiver Installer
- `.env.example` — Variablen-Template
- `db/seeds/` — Initial-Lookup-Daten (Genres, Event-Typen)

---

## 5. Bei der GHCR einloggen

Nimm den per Mail erhaltenen Token (sieht aus wie `ghp_...` oder `github_pat_...`):

```sh
echo "<DEIN-TOKEN>" | docker login ghcr.io -u <github-user-aus-mail> --password-stdin
```

Erwartete Ausgabe:
```
Login Succeeded
```

> **Synology:** mit `sudo docker login ...` — der Daemon-Socket gehört root.
> Token wird auf der Festplatte unter `/root/.docker/config.json` abgelegt.

> **Token nie in Slack / Mail / Repo posten!** Wenn du ihn versehentlich
> öffentlich gemacht hast: sofort Mail an hallo@feinfein.de — wir
> revoken und stellen einen neuen aus.

---

## 6. install.sh ausführen

```sh
./install.sh             # Linux mit Docker-Gruppe oder macOS
sudo ./install.sh        # Synology
```

Beim ersten Lauf fragt das Script ein paar Werte ab (alle mit sinnvollen
Defaults — Enter übernimmt):

| Prompt | Default | Was es bedeutet |
|---|---|---|
| `DATA_ROOT` | `./data` | Wo Container-Daten liegen sollen (DB, Uploads, Logs) |
| `PUBLIC_TENANT_SLUG` | `feinfein` | Identifier für Multi-Tenant-Themes (Standardwert behalten ist ok) |
| `TLS_MODE` | `extern` | `extern` = TLS macht Synology / Reverse-Proxy / kein TLS. `traefik` = Sidecar-Container mit Lets-Encrypt |
| Bei `traefik`: Domains + Mail | — | Eure Domains für API, Suite-UI, ggf. WebPlaner |
| `PUBLIC_BASE_URL` | `https://spielplaner.example` | Externe URL der Suite (HTTPS, ohne abschließenden /) |
| `OIDC_ISSUER` | identisch | Meist gleich `PUBLIC_BASE_URL` |
| `BOOTSTRAP_ADMIN_EMAIL` | `admin@example.com` | Adresse für Welcome- und Reset-Mails (kann später geändert werden) |
| `SMTP_FROM` | `no-reply@example.com` | Absender-Adresse für ausgehende Mails |
| `ENABLE_WEBPLANER` | `0` | `1` = öffentliche Theater-Website mit installieren |

DB-Passwörter, JWT-Secret und Cron-Token werden automatisch generiert
(`openssl rand`). Du musst nichts in die `.env` händisch eintragen.

Der erste Lauf dauert je nach Netz/Server **5–15 Minuten** (Image-Pull
+ DB-Init). MariaDB-Init auf Synology-Btrfs braucht ~3 Min — das ist
normal.

---

## 7. Setup-Wizard im Browser

Wenn install.sh durch ist, öffne im Browser:

```
http://<dein-server>:3000/setup
```

Der Wizard fragt dich Schritt für Schritt:

1. **Theater** — Anzeigename (für Mails und PDFs)
2. **Admin-Account** — Benutzername (≥3 Zeichen), Passwort (≥12 Zeichen),
   E-Mail (für Reset-Mails)
3. **Firmendaten** — Firmenname (Pflicht), Adresse, USt-Id, Telefon
   (für Mail-Footer und Reports)
4. **SMTP** — optional, kann übersprungen werden

Klick „Installieren" → Redirect zur Login-Seite. Dann mit Admin einloggen
und unter *Mein Konto → 2FA* die Zwei-Faktor-Authentifizierung aktivieren.

---

## 8. Was du danach tust

- **Stammdaten füllen** (Räume, Genres, Event-Typen) — viele Defaults sind
  vorgeladen.
- **Bundesland** unter *Stammdaten → Firmendaten* setzen — steuert
  Feiertage und Schulferien im Kalender.
- **Erste Mitarbeiter:innen einladen.**
- **Backup einrichten** (`scripts/db-backup.sh`) — siehe Operations-Doku.

---

## 9. Updates einspielen

```sh
cd spielplaner
git pull                                       # neue compose.yml + neue Tags
$EDITOR .env                                   # IMAGE_TAG anpassen, falls neuer Release
docker compose pull                            # neue Images ziehen
./install.sh                                   # idempotent — startet Stack mit neuen Images
```

---

## 10. Probleme?

- **„manifest unknown"** beim Pull → falscher Token, oder Token läuft ab.
  Mail an hallo@feinfein.de.
- **„Bind mount failed"** → Verzeichnis-Berechtigungen. Auf Synology
  `chmod 755` für `data/` setzen.
- **DB startet nicht** → `sudo docker logs spielplaner-db-1` — meist
  Port-Konflikt mit anderem MariaDB.
- **Browser-Wizard zeigt 409** → Setup wurde schon durchlaufen. Direkt
  zu `/login` springen.

Sonstige Fragen: **hallo@feinfein.de** mit Logs (`sudo docker compose logs --tail=200`).

---

## Lizenz-Erinnerung

Diese Software wird unter **PolyForm Noncommercial License 1.0.0** überlassen.
**Kommerzielle Nutzung ist ohne separate schriftliche Lizenz-Vereinbarung
nicht gestattet.** Vollständiger Text: [LICENSE](LICENSE).
