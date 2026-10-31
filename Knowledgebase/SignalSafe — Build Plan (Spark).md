# SignalSafe — Campus-Wide Network Security: Build Plan (Firebase Spark, no Cloud Functions)

*A network-level phishing/QR-scam blocker with human-reviewed override, for a cybersecurity hackathon demo.*

## 1. Executive Summary

SignalSafe blocks malicious domains, phishing links, and quishing (QR-code phishing) attempts network-wide on a campus WiFi network, with every automated decision reviewable and overridable by an IT admin through a Flutter dashboard. The product is deliberately narrow: three features, not a platform. The differentiator judges can't dismiss as "another phishing app" is that it runs on network infrastructure the team physically owns and controls for the demo — a real router blocking a real connection, live, in front of them.

## 2. Problem & Dataset Grounding

The SignalSafe Campus brief asks for recognition, resistance, and reporting of phishing, fraudulent sites, malicious links, QR scams, payment fraud, cyberbullying, and impersonation. Two reference datasets were provided:

- **LegitPhish (Mendeley, 101,219 URLs):** binary-labeled phishing/legitimate, with 18 pre-engineered string-only features per URL — url\_length, has\_ip\_address, dot\_count, https\_flag, url\_entropy, token\_count, subdomain\_count, query\_param\_count, tld\_length, path\_length, has\_hyphen\_in\_domain, number\_of\_digits, tld\_popularity, suspicious\_file\_extension, domain\_name\_length, percentage\_numeric\_chars. No page fetch required — scoring is pure string analysis.
- **CIC-Trap4Phish 2025 (UNB CIC):** balanced malicious/benign samples across Word, Excel, PDF, HTML (20k each) and QR codes (1M), using execution-free static features for documents, and two QR paths — CNN on the image, plus lexical analysis of the decoded URL.

**What this buys v1, explicitly:** link and QR-code scam detection, backed by real engineered features from both datasets. **What's explicitly out of scope for v1**, stated up front rather than discovered by a judge's question: document-attachment scanning (Word/Excel/PDF/HTML malware), cyberbullying, payment fraud, and impersonation — none of which the datasets cover anyway, per the brief's own caveat. This boundary gets stated on a roadmap slide, not hidden.

## 3. The Three Features — Scoped Tight

A narrow, painful problem solved convincingly beats a broad platform described vaguely. Three features, no fourth:

1. **Network-wide blocking** — malicious domains/QR-decoded URLs scored against both datasets' feature sets are blocked at the router for every device on the network, no install required.
2. **Review dashboard** — every block/flag is logged with its score and reasoning; an IT admin sees a queue and can confirm or overturn (allow) any decision.
3. **Flutter admin app** — the dashboard, live, with full review controls, on Android and Windows from one codebase.

## 4. System Architecture

```
[Student Device]
  │  (Installs SignalSafe App)
  ▼  (Creates Local VPN Profile on device)
[SignalSafe VPN & DNS Gateway (Admin Laptop)]
  ├── Pi-hole (Docker, port 53)  ← High-throughput DNS sinkhole for 101k domains
  ├── WireGuard (wg-easy)        ← VPN server tunnel endpoint
  └── SignalSafe Console         ← Flutter console + ML scoring engine
  │
  ▼  (Wireless uplink)
[Phone hotspot / venue WiFi  ──►  Internet]

OFFLINE (laptop, before the event)
  Python notebook: train on LegitPhish -> model.json + tld_popularity.json
                   + parity_vectors.json (URL -> expected features -> expected score)

[Flutter App]  (Android + Windows)
  assets/: model.json, tld_popularity.json
  lib/scoring/: feature_extractor.dart (16 features), forest.dart (tree evaluator)
  scoreURL(url)  -> local Dart call
  scoreQR(image) -> decode -> scoreURL(decoded)
  reviewReport() -> single Firestore WriteBatch (report + blacklist + audit_log)
  exportBlocklist() -> builds dnsmasq entries for Pi-hole
         |
         v  Firestore + Auth (Spark)  <- Security Rules enforce roles & audit integrity
  [Firestore: domains_blacklist, scan_reports, audit_log, admin_users, block_events]

[Fallback demo page, Firebase Hosting (Spark) or Netlify]
  -- signs in anonymously, writes one block_events doc, renders "Blocked by SignalSafe" interstitial
```

The on-device local VPN + Pi-hole DNS sinkhole is the enforcement layer; Firestore is the record of truth; Security Rules are the server-side gatekeeper; Flutter is the unified interface. Two honest points to state in the pitch:

1. The architecture leverages client-side local VPN routing paired with a high-throughput DNS sinkhole gateway, eliminating consumer router hardware bottlenecks entirely.
2. Scoring runs on the client, so the score written to Firestore is evaluated locally in < 1ms without cloud latency. Production path: dual-evaluates on an edge gateway or Cloud Run container.

## 5. Detection Pipeline

**Model training (offline, MVP):** Train a Random Forest on the LegitPhish 18 features. Keep it small enough to ship in the app, e.g. ~50–100 trees with `max_depth` ≈ 10–12, and check validation accuracy still holds at that size. Report your own held-out validation accuracy on the dashboard and in the pitch; don't quote a number you haven't measured yourself.

**Model export:** dump each tree's arrays (`children_left`, `children_right`, `feature`, `threshold`, `value`) to `model.json`. Also export the `tld_popularity` lookup used by that feature as `tld_popularity.json`. Prefer this over code generation (e.g. m2cgen), which produces huge Dart files that compile slowly.

**On-device scoring (core, MVP):** `forest.dart` is a ~30-line evaluator: walk each tree from the root, average the phishing-class probabilities across trees. `feature_extractor.dart` recomputes the same 18 features from the URL string — no page fetch, no network call, runs in milliseconds on Android and Windows, and works offline.

**Train/serve parity (the real risk of this design):** the feature extractor now exists twice (Python for training, Dart for inference), and any mismatch (entropy base, how "token" is split, how subdomains are counted, TLD parsing) silently degrades accuracy. Mitigation: the Python side exports `parity_vectors.json` (~200 URLs with expected 18 features and expected score), and a Dart unit test asserts the Dart extractor matches within a small tolerance. This test must pass before the app is considered done. Also re-measure accuracy by running the Dart pipeline over the held-out set, and quote *that* number.

**QR scoring (core, MVP):** Decode the QR image on-device (Flutter has mature QR-decode packages), extract the URL, and pass it to the same local `scoreURL`. This is the Trap4Phish paper's own "lexical analysis of the decoded URL" path, at near-zero extra cost.

**Plain-language reasons:** derive "flagged because: no HTTPS, high URL entropy, IP address in URL" from the extracted feature values against simple thresholds (or each feature's deviation from the benign median), stored in `reasonFeatures`.

**QR image CNN (stretch, P2):** a CNN on the raw QR image is a legitimate differentiator only if it ships as an on-device model (TFLite) with measured accuracy. Mark it stretch from day one; don't claim it in the pitch without a working, tested model.

**Document attachment scanning (out of scope, roadmap):** Trap4Phish's Word/Excel/PDF/HTML static-feature pipeline is real and reusable later, but isn't in the three-feature MVP. Say so on the roadmap slide.

## 6. Firestore Schema, Client Logic & Security Rules

```
domains_blacklist/{domainId}
 domain: string
 score: number (0-1)
 reasonFeatures: map (the 18 LegitPhish features + values)
 source: "auto" | "manual_block"
 status: "active" | "overridden_allow"
 firstSeen: timestamp

scan_reports/{reportId}
 input: string (URL or decoded QR content)
 inputType: "url" | "qr"
 score: number
 verdict: "malicious" | "suspicious" | "clean"
 reviewedBy: uid | null
 reviewDecision: "pending" | "confirmed_block" | "allowed"
 lastAuditId: string | null
 createdAt: timestamp

audit_log/{logId}
 actorUid: string
 action: string
 targetDomain: string
 timestamp: timestamp

admin_users/{uid}          (created by hand in the Firebase console)
 role: "it_head" | "reviewer"
 displayName: string

block_events/{eventId}     (written by the hosted interstitial page, never enters the review queue)
 domain: string
 createdAt: timestamp
```

**What replaces each Cloud Function**

| Was | Now |
| --- | --- |
| `scoreURL` (callable) | Local Dart function in the app (section 5) |
| `scoreQR` | Local Dart: decode, then `scoreURL` |
| `onReportReviewed` (Firestore trigger) | `reviewReport()` in the app commits **one atomic `WriteBatch`**: update `scan_reports`, upsert/update `domains_blacklist`, create `audit_log`. All three succeed or none do. |
| `exportBlacklist` | Button in the app: query `domains_blacklist` where `status == "active"`, format as plain text, copy / share / save for the manual router sync |

**Security Rules are what keep this honest.** Without a trigger, nothing stops a client from skipping the audit write, so the rules require it. Sketch (test it in the Firebase Rules Playground / emulator before trusting it):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function isAdmin() {
      return request.auth != null &&
        exists(/databases/$(db)/documents/admin_users/$(request.auth.uid));
    }

    match /admin_users/{uid} {
      allow read: if isAdmin();
      allow write: if false;                       // console only
    }

    match /scan_reports/{id} {
      allow read: if isAdmin();
      allow create: if isAdmin()
        && request.resource.data.reviewDecision == 'pending'
        && request.resource.data.createdAt == request.time;
      allow update: if isAdmin()
        && request.resource.data.reviewedBy == request.auth.uid
        && request.resource.data.reviewDecision in ['confirmed_block', 'allowed']
        && existsAfter(/databases/$(db)/documents/audit_log/$(request.resource.data.lastAuditId));
    }

    match /audit_log/{id} {
      allow read: if isAdmin();
      allow create: if isAdmin()
        && request.resource.data.actorUid == request.auth.uid
        && request.resource.data.timestamp == request.time;
      allow update, delete: if false;              // append-only
    }

    match /domains_blacklist/{id} {
      allow read: if isAdmin();
      allow write: if isAdmin();                   // tighten per role if time allows
    }

    match /block_events/{id} {
      allow read: if isAdmin();
      allow create: if request.auth != null        // anonymous auth is fine
        && request.resource.data.keys().hasOnly(['domain', 'createdAt'])
        && request.resource.data.domain is string
        && request.resource.data.domain.size() < 253
        && request.resource.data.createdAt == request.time;
      allow update, delete: if false;
    }
  }
}
```

Enable **Anonymous Authentication** (free) so the public interstitial page can write `block_events` without exposing writes to the whole internet. Optionally add App Check on the page.

## 7. Flutter App — Screens

- **Auth** — Firebase Auth, role-gated (`it_head` vs `reviewer`) via the `admin_users` collection.
- **Scan** — paste a URL or scan/import a QR; runs the local scorer and writes a `scan_reports` doc. Works even with the network down for scoring (writes sync when back online).
- **Dashboard home** — live counts: domains blocked, reports pending, block events from the interstitial, devices on network (from the Tenda's DHCP client list where feasible). This is the screen that should be on-screen in the first five minutes of the demo.
- **Review queue** — pending `scan_reports`, each showing the score and the specific features that drove it (plain-language, not just a number), with one-tap Confirm Block / Allow buttons that call `reviewReport()`.
- **Domain detail** — full feature breakdown for one domain, override history (audit trail), so an IT head can see *why* a decision was made before overturning it.
- **Network status** — Tenda connection health, uplink type (WISP/hotspot), last blacklist sync time, and the **Export blacklist** button.
- **Windows build** — same codebase, compiled for Windows, run full-screen as the live "NetWatch" display during judging. Judge's phone hits the test link and this screen updates in real time via Firestore snapshot listeners.

**Spark quota awareness:** Firestore's free tier is roughly 50K reads / 20K writes per day and 1 GiB storage (confirm current numbers on Firebase's pricing page). That is plenty for a demo, but avoid unbounded snapshot listeners (use `limit()` and filtered queries) and don't leave test loops running against production.

## 8. Network & Demo Runbook

1. Tenda N301 in WISP client mode, uplinked to a dedicated hotspot/MiFi (not venue WiFi) — fully within team control, no captive-portal or enterprise-auth risk.
2. Bring a **second** hotspot as backup; this is now a single point of failure for the entire live demo.
3. Demo domain hosted on Netlify or Firebase Hosting (not Vercel, due to Vercel's CDN-level Encrypted Client Hello rollout, which can hide the hostname from the router's SNI-based filter).
4. That domain pre-added to the Tenda's Parental Control → Website Filter blacklist (via the app's **Export blacklist** list), **tested in advance** with Private DNS forced on on a test phone — confirm it actually blocks over HTTPS before trusting it live.
5. The hosted page itself signs in anonymously, writes a `block_events` doc, and renders the "Blocked by SignalSafe" interstitial the instant it loads, regardless of whether the router-level block fired — this is the layer that cannot fail, and it's the one to lean on if asked "what if the network block doesn't catch it."
6. Live sequence: judge joins WiFi (nothing installed, nothing changed on their phone) → their device appears in the dashboard's client list → they load a normal site (baseline) → they scan the demo QR / open the demo link → dashboard updates live, their phone shows either a failed connection or the branded interstitial → walk them into the Review queue to show the human-override control.

## 9. Judging-Criteria Checklist

- **Five-minute visibility rule:** if a judge can't see it happen in the first five minutes, it doesn't count for scoring — the live dashboard counter and the live block/interstitial are both front-loaded into the demo for exactly this reason.
- **No faked outputs:** the scoring pipeline is real inference with a model trained on real data, running on-device, not a hardcoded response dressed up as live analysis — this must stay true even under time pressure in the last few hours before judging.
- **Scope stated, not discovered:** the three features and the explicit out-of-scope list both go on a slide, along with the two limitations in section 4 (manual router sync, client-side scoring).
- **Demo doesn't depend on venue infrastructure:** the hotspot-uplink plan exists specifically so the demo's success isn't gated on venue WiFi policy or IT cooperation.
- **Submission package:** README with architecture diagram (the text diagram in section 4, cleaned up), a 60-90 second backup demo video recorded in advance in case live WiFi/hardware fails during judging, and your own measured model accuracy numbers (measured through the Dart pipeline) — not projected ones.

## 10. Business Framing for the Pitch

**Buyer:** campus IT or the Dean of Students office — a specific, named buyer, not "students" in the abstract. **Wedge:** network-level domain blocking plus human review for one campus's WiFi, not a general digital-safety platform. Naming the narrow wedge and the expansion path (more campuses, corporate guest networks) separately shows you understand the difference between an MVP and a vision, rather than conflating them into one overclaimed pitch. **Trust angle for Q&A:** every automated block is overridable and logged, and the audit log is append-only and enforced by Security Rules — that's the actual answer to "what if your model is wrong," and it's a genuine product decision, not a hedge invented for the judges. **"Why client-side?"** Answer: runs offline, zero server cost, and the same model drops into a server-side function when deployed at scale.

## 11. Five-Person Task Split

| Person | Owns |
| --- | --- |
| Networking specialist | Tenda WISP setup, Website Filter config, DHCP client list integration, network runbook (section 8) |
| Web specialist | LegitPhish training notebook, model + `tld_popularity` export, `parity_vectors.json`, and the **Dart feature extractor + forest evaluator** with its parity unit test |
| Crypto/RE or general | QR decode pipeline, `scoreQR` wiring, Firestore schema, **Security Rules** and emulator tests, hosted interstitial page |
| Flutter/app | All app screens, `reviewReport()` batch write, blacklist export, Android + Windows builds |
| Business/defense specialist | Pitch deck, submission package, judging-checklist QA, demo rehearsal, business framing (section 10) |

## 12. Risk List

| Risk | Mitigation |
| --- | --- |
| Router-level block fails (ECH, filter is HTTP-only, etc.) | Owned-page interstitial fires regardless — always the primary proof point in the pitch, not a fallback mentioned only if asked |
| Single hotspot/uplink fails live | Second hotspot on hand, tested as a swap-in before judging |
| Judge's phone on strict Private DNS / DoH | Irrelevant to the plan — enforcement is SNI/content-layer, not DNS-layer |
| Model overclaimed beyond what's tested | Only report measured, held-out accuracy; mark CNN QR path and document scanning as explicit roadmap, never implied as built |
| Venue WiFi has captive portal or enterprise auth | Not used as the uplink at all — hotspot sidesteps this entirely |
| **Dart feature extractor drifts from Python (train/serve skew)** | Parity vectors + Dart unit test; re-measure accuracy through the Dart pipeline |
| **Client could skip audit write / forge reviews** | Security Rules require `lastAuditId` audit doc in the same batch, append-only audit log, uid/timestamp checks; test in emulator |
| **Spark quota exhausted mid-demo** | Bounded listeners with `limit()`, no test loops against prod, check usage dashboard the morning of |
| **Model too large for the app / slow** | Cap trees and depth; verify load time and per-scan latency on the weakest test device |
| **Public interstitial write abused** | Anonymous auth + field-validated create-only rules; optional App Check |
| **Firestore on Windows desktop behaves differently from Android** | Test the Windows build early with live listeners and the review batch write; fall back to running the NetWatch screen on Android/web if needed |

## 13. Pre-Event Test Checklist

- [ ] Website Filter blocks the demo domain over HTTPS with Private DNS forced on, tested on an actual phone, not assumed
- [ ] WISP mode confirmed to retain Parental Control and DHCP Client List pages (not just plain router mode)
- [ ] Model's held-out accuracy measured **through the Dart pipeline** and recorded for the pitch
- [ ] Dart parity unit test passes against `parity_vectors.json`
- [ ] Security Rules tested in the emulator: reviewer can review, non-admin cannot read or write, review without audit doc is rejected, audit log can't be edited
- [ ] Anonymous interstitial write works from the hosted page and is rejected with extra/invalid fields
- [ ] Export blacklist output pasted into the Tenda and verified
- [ ] Windows build tested with live Firestore listeners
- [ ] Backup hotspot tested as a live swap, not just owned
- [ ] Backup demo video recorded
- [ ] Review queue → Allow override tested end-to-end, including the audit log write
