# 🛡️ SignalSafe — Campus-Wide Network Security & Phishing/QR Defense

> **A physical network-level phishing and quishing blocker with an immutable human-reviewed override console, grounded in Mendeley LegitPhish (101,219 URLs).**

---

## 🌟 Executive Summary

SignalSafe blocks malicious domains, credential harvesters, and quishing (QR-code phishing) attempts network-wide on campus WiFi without requiring students to install apps or security profiles. Built on real network infrastructure (Tenda N301 WISP mode), decisions are evaluated locally on-device in under 1 millisecond and governed by an IT Admin console with atomic batch human overrides and append-only audit trails.

---

## 📊 Measured Machine Learning Validation Metrics

Trained on the Mendeley LegitPhish dataset (101,218 valid samples, 16 lexical and structural features):

| Metric | Measured Score | Training Grounding |
|---|---|---|
| **Held-Out Validation Accuracy** | **99.96%** | 20,244 held-out URLs (80/20 stratified split) |
| **Precision** | **99.95%** | Class 1 (Phishing / Malicious) |
| **Recall** | **99.98%** | Phishing detection sensitivity |
| **F1 Score** | **99.96%** | Harmonic mean |
| **ROC-AUC** | **1.0000** | Area Under Receiver Operating Characteristic |
| **Dart Inference Parity Test** | **99.50%** | Measured through local Dart feature extractor & evaluator |
| **On-Device Inference Latency** | **< 1 ms** | 50 compact decision trees in memory |
| **Model Footprint** | **206 KB** | `assets/model.json` (zero external ML dependencies) |

---

## 🏗️ System Architecture

```
[Judge / Student Phone]
      │
      ▼  (Zero-install WiFi association)
[Tenda N301 Router, WISP Mode]
      ├── Hardware Website Filter Blacklist (synced pre-demo from NetWatch export)
      └── DHCP Client Pool Table (live connected-device visibility)
      │
      ▼  (Wireless Uplink)
[Dedicated 4G/5G Hotspot / MiFi]
      │
      ▼
   Internet

[SignalSafe NetWatch Console] (Windows Desktop / Web / Android)
      ├── assets/model.json (50-tree compact Random Forest)
      ├── assets/tld_popularity.json (TLD reputation map)
      ├── lib/scoring/feature_extractor.dart (16 lexical features computed offline)
      ├── lib/scoring/forest.dart (On-device decision tree evaluator)
      ├── lib/scoring/reasoning.dart (Plain-language IT explanation derivation)
      ├── lib/services/database_service.dart (Atomic review batch transactions & reactive streams)
      └── lib/services/export_service.dart (Tenda N301 plain text blacklist generator)

[Hosted Interstitial Fallback Page] (Firebase Hosting / Local)
      └── Renders "Blocked by SignalSafe" interstitial and logs anonymous block_events
```

---

## 🎯 The Three Core Features

1. **Network-Wide Blocking:**
   - Any malicious link or QR scam scored against the 16-feature vector is blocked at the physical router level for all devices on the network.
   - Requires zero software installation on student or guest devices.

2. **SecOps Review Queue & Human Override:**
   - Every automated detection enters a human-in-the-loop triage queue with plain-language reasoning.
   - IT Admins can confirm the block or issue an allowlist override in one tap.
   - Enforced by an atomic batch transaction updating reports, blacklists, and append-only audit trails simultaneously.

3. **Flutter NetWatch Console (Windows & Mobile):**
   - Live telemetry dashboard featuring active blocked domains, pending reviews, interstitial hits, and connected DHCP client visibility.
   - Interactive QR code generator for live physical testing with judging phones.

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (>= 3.11.3)
- Python 3.10+ (for model re-training if desired)

### Running the App
```bash
# Get dependencies
flutter pub get

# Run on Windows Desktop (recommended for live demo)
flutter run -d windows

# Or run in Google Chrome
flutter run -d chrome
```

### Running the Parity Verification Test
Verify train/serve parity between scikit-learn and the Dart inference engine:
```bash
flutter test test/parity_test.dart
```

### Re-training the Model (Optional)
```bash
python scripts/train_model.py
```

---

## 📁 Repository Structure

```
signalsafe/
├── assets/
│   ├── model.json               # 50-tree Random Forest weights (206 KB)
│   ├── tld_popularity.json      # TLD reputation map
│   └── parity_vectors.json      # 200 held-out verification samples
├── lib/
│   ├── models/                  # Domain, ScanReport, AuditLog, AdminUser, DhcpClient
│   ├── scoring/                 # FeatureExtractor, ForestEvaluator, DetectionReasoning
│   ├── services/                # DatabaseService (Atomic Batches), ScoringService, ExportService
│   ├── theme/                   # Cyber dark mode theme
│   ├── ui/                      # Dashboard, Scan, ReviewQueue, DomainDetail, NetworkStatus
│   └── main.dart                # Application entry point
├── scripts/
│   └── train_model.py           # Scikit-learn Random Forest training pipeline
├── hosting/public/
│   └── index.html               # "Blocked by SignalSafe" fallback interstitial page
├── firestore.rules              # Role-gated immutable audit trail rules
├── firebase.json                # Spark hosting, firestore, and emulator setup
├── DEMO_RUNBOOK.md              # 5-minute live judging script & hardware guide
└── test/
    ├── parity_test.dart         # Train/serve 200-sample verification test
    └── widget_test.dart         # Widget smoke test
```

---

## 🛡️ License

Built for cybersecurity hackathon evaluation. Grounded in the Mendeley LegitPhish dataset.
