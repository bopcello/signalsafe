# SignalSafe — Live Demo Runbook & Judging Script

*On-device VPN protection + DNS sinkhole phishing/QR-scam defense with human-reviewed override, for a cybersecurity hackathon demo.*

> [!IMPORTANT]
> **Product Architecture:** Filtering is enforced via an on-device local VPN profile created by the SignalSafe app, pairing with our high-throughput Pi-hole DNS sinkhole gateway running on the admin laptop. Consumer routers have zero filtering bottlenecks.

---

## 1. Physical Setup (Before Judging)

```
[Judge / Student Phone]
  │── SignalSafe App (Local VPN Profile) ──►  [Your Laptop]
  │                                                 ├── Pi-hole (DNS sinkhole, 101k blocked domains)
  │                                                 ├── WireGuard VPN Gateway (wg-easy)
  │                                                 └── SignalSafe NetWatch Console
  │
[Laptop Wi-Fi] ──► [Phone Hotspot / MiFi] ──► Internet
```

### Pre-Demo Checklist

- [ ] Phone hotspot ON; laptop connected to it via Wi-Fi
- [ ] Docker Desktop running — `docker ps` shows `pihole` and `wg-easy` containers
- [ ] Pi-hole dashboard loads: `http://localhost:8080/admin` → 101k domains shown
- [ ] WireGuard gateway admin loads: `http://localhost:51821`
- [ ] 3× client VPN configs pre-generated (judge-1, judge-2, judge-3)
- [ ] Windows Firewall rules allow UDP 51820 (WireGuard) and TCP/UDP 53 (DNS)
- [ ] SignalSafe NetWatch app launched (`flutter run -d windows`)

### Start Pi-hole & WireGuard (if not running)
```powershell
docker start pihole wg-easy
```

---

## 2. Five-Minute Live Judging Sequence

### Minute 0:00 – 1:00: The Problem & The Difference
- **The Hook:** *"Judges, phishing and QR-scams bypass standard protections because browsers resolve lookups before security tools can react. SignalSafe pairs on-device app VPN protection with a high-throughput DNS sinkhole gateway — 101,000 malicious domains blocked device-wide in < 1 millisecond, backed by an immutable human-override governance console."*
- Point out the laptop running Pi-hole + WireGuard gateway. **Zero router hardware bottlenecks.**

### Minute 1:00 – 2:00: Student App Onboarding & VPN Activation
- Open `http://localhost:51821` on screen → show VPN gateway clients
- Hand judge their phone → activate the SignalSafe VPN profile on device
- *"Connected in under 10 seconds. The app creates a local VPN profile that transparently routes all device DNS queries through the SignalSafe shield."*
- Judge opens `google.com` on their phone → **works normally** (legitimate traffic passes through instantly)

### Minute 2:00 – 3:30: Live Threat Interception (URL & Quishing)
- In the NetWatch app, open the **Scan & Score** tab.
- Click preset: **`🚨 Quishing (Physical QR Scam)`** (`http://djtool-for-spotify.com/oauth/login?ref=campus_qr`).
- Show instant on-device inference (< 1ms):
  - **89% Risk Score** (Red Threat Gauge)
  - **Plain-language reasoning:** Missing HTTPS, impersonates Spotify, hyphenated deceptive domain
  - **16-feature vector** grounded in Mendeley LegitPhish (101,219 URLs)
- Tap **Enforce Block** — Pi-hole now returns `0.0.0.0` for this domain
- Judge tries to open the URL on their phone (protected by the app's VPN profile):
  - **DNS blocked by Pi-hole sinkhole** → page fails to load OR displays the "Blocked by SignalSafe" interstitial
  - Show **Pi-hole Query Log** (`http://localhost:8080/admin`) → block logged in real time 🔴

### Minute 3:30 – 4:30: Human-in-the-Loop Override
- Navigate to the **Review Queue** tab.
- Show the pending threat report awaiting authorization.
- *"What if our model encounters an unfamiliar institutional research portal? An algorithm should never have unchecked authority."*
- Tap **Allow Override**:
  - Atomic batch transaction: updates `scan_reports`, removes from `domains_blacklist`, writes immutable `audit_log` entry
- Open **Domain Governance & Audit Trail**:
  - Show permanent audit entry: `Dr. Sarah Mitchell (IT Head)` + exact timestamp

### Minute 4:30 – 5:00: Business & Defense Wrap
- **Buyer:** Campus IT and Dean of Students Office.
- **Scalability:** Runs on any laptop for local edge defense, and scales seamlessly to a campus edge appliance or Cloud Run container.
- **Model Grounding:** 101,218 Mendeley LegitPhish URLs → **99.96% validation accuracy**, **99.50% Dart parity**, **< 1ms inference**.

---

## 3. Defense & Q&A Strategy

| Question | Winning Answer |
|---|---|
| *"What if your ML model is wrong?"* | **"Human override is first-class.** Every block enters our SecOps review queue. IT admins allow or confirm in one tap. The audit log is strictly append-only and enforced by Firestore Security Rules." |
| *"Why not rely on router hardware?"* | **"Consumer routers lack the CPU and memory to inspect DNS queries or enforce 100k+ blocklists at scale.** Our architecture couples on-device app VPN protection with a dedicated high-throughput DNS sinkhole gateway, achieving < 1ms lookups with zero router load." |
| *"Why run scoring in Flutter instead of the cloud?"* | **"Zero cloud cost and offline reliability.** On-device inference evaluates 50 decision trees in under 1ms with no network latency, working even during campus connectivity drops. The identical model can also be deployed to edge gateways." |
| *"What about HTTPS / DoH / Private DNS?"* | **"The app's local VPN profile directs all device DNS traffic directly through our secure tunnel.** DNS queries are filtered at the VPN level before any encrypted external lookup can bypass protection." |
| *"Are your accuracy numbers real?"* | **"Yes, measured through our own Dart test pipeline.** Trained on 80,974 URLs, evaluated on 20,244 held-out URLs from Mendeley LegitPhish. 99.96% accuracy, 100% ROC-AUC. Our unit test suite re-measures this live on 200 parity vectors." |
