# SpielPlaner — Installer

> © Frank-Christian Struve 2026
> Lizenz: **PolyForm Noncommercial 1.0.0** — siehe [LICENSE](LICENSE).
> **Kommerzielle Nutzung erfordert eine separate Lizenz** (Kontakt: hallo@feinfein.de).

Plug-and-Play-Installation des **SpielPlaner** plus optional **WebPlaner**.

Lokales Deployment, keine Cloud, keine externen Logins. Container-Images
liegen in einer **privaten** [GitHub Container Registry](https://ghcr.io/spielplaner) —
fuer den Image-Pull braucht es einen Personal Access Token (PAT) mit
`read:packages`-Scope. Den PAT bekommst du nach Lizenz-Vereinbarung
direkt vom Lizenzgeber.

## Voraussetzungen

| Komponente | Mindestversion |
|---|---|
| OS | macOS 13 / Linux (Debian, Ubuntu, DSM 7.2) |
| Docker | 24.0+ mit `docker compose` v2 |
| RAM | 4 GB frei |
| Plattenplatz | 5 GB initial, +1 GB/Jahr Audit-Log |
| Open Ports (Default) | 3000 (Web), 8000 (API), optional 3001 (WebPlaner), 80/443 (Traefik) |

## Schnellstart

```sh
git clone https://github.com/spielplaner/install.git spielplaner
cd spielplaner

# 1) Bei der privaten GHCR einloggen (einmalig pro Host).
#    PAT mit Scope read:packages — bekommst du vom Lizenzgeber.
echo $GHCR_PAT | docker login ghcr.io -u <dein-github-user> --password-stdin

# 2) Installation starten
./install.sh
```

`install.sh` fragt beim ersten Lauf interaktiv ab:
- Wo Daten liegen sollen (`DATA_ROOT`)
- Tenant-Slug (Default `feinfein`)
- TLS-Modus: `extern` (Synology/Reverse-Proxy) oder `traefik` (Sidecar mit Lets-Encrypt)
- Public-URL der Suite, OIDC-Issuer, Admin-Email, SMTP-From-Adresse
- WebPlaner mit-installieren: ja/nein

Datenbank-Passwoerter, JWT-Secret und Cron-Token werden automatisch
generiert. Nach dem Start: Browser auf `http://<host>:3000/setup` —
dort werden Theatername, Admin-Account, Firmendaten und (optional)
SMTP konfiguriert.

### Hinweise pro Plattform

**Linux (Debian, Ubuntu, …):** Nutzer in die `docker`-Gruppe aufnehmen
(`sudo usermod -aG docker $USER`, dann ausloggen + neu einloggen) —
danach laufen die docker-Befehle ohne sudo.

**Synology DSM (Container Manager):** Es gibt keine `docker`-Gruppe;
docker-Befehle brauchen root. Den Installer entsprechend mit `sudo`
starten. Fuer wiederholtes Debugging optional NOPASSWD setzen:

```sh
sudo -i
echo 'YOURUSER ALL=(ALL) NOPASSWD: /usr/local/bin/docker' > /etc/sudoers.d/docker-nopasswd
chmod 440 /etc/sudoers.d/docker-nopasswd
exit
```

**macOS (Docker Desktop):** docker laeuft als Desktop-App, kein sudo.
Installer wie auf Linux ohne sudo starten.

## Was hier liegt

```
.
├── compose.yml         # Docker-Compose-Definition (alle Services + Profile)
├── install.sh          # Interaktiver Installer (Tech-Konfig + Stack-Start)
├── .env.example        # Variablen-Template
└── db/seeds/           # Initial-Lookup-Daten (Genres, Schulferien etc.)
```

## Update

`compose.yml` ist auf eine konkrete Version gepinnt (`IMAGE_TAG=vX.Y.Z`
in `.env`). Update-Ablauf:

```sh
git pull
$EDITOR .env                         # IMAGE_TAG anpassen, falls noetig
docker compose pull
./install.sh                         # idempotent: ueberschreibt nichts
```

## Was hier NICHT liegt

- Quellcode (privat in `spielplaner/spielplaner` und `spielplaner/webplaner`)
- Issues — Bugs bitte direkt in den Source-Repos melden
- Doku — siehe Source-Repo `docs/`

## Generierung

Diese Dateien werden **automatisch** aus dem Source-Repo
`spielplaner/spielplaner` generiert (Skript `scripts/generate-installer.sh`,
ADR-0002). Manuelle Edits hier werden beim naechsten Sync ueberschrieben —
Bug-Reports und Verbesserungen bitte am Source-Repo.

## Lizenz

**PolyForm Noncommercial License 1.0.0** — siehe [LICENSE](LICENSE).

Kurz:
- ✅ Erlaubt für Theater (gemeinnuetzig), Schulen,
  Bildungseinrichtungen, Forschung, Privatpersonen
- ❌ **Nicht erlaubt** ohne separate Lizenz: Verkauf, kostenpflichtige
  SaaS-Angebote, Integration in kommerzielle Produkte, Vermietung
- 📩 Kommerzielle Lizenz auf Anfrage: **hallo@feinfein.de**
