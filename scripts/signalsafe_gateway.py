#!/usr/bin/env python3
"""
SignalSafe Campus Edge Gateway & Threat Interceptor
===================================================
1. Loads all 26,889+ phishing domains from Mendeley LegitPhish dataset
   (Knowledgebase/datasets/url_features_extracted1.csv).
2. Runs a high-performance DNS Sinkhole on port 53 (UDP):
   - Blocks any attempt by connected student/judge devices to access dataset threats.
   - Transparently forwards all clean traffic (Google, YouTube, etc.) to 1.1.1.1.
3. Captures the exact Client IP of the device making the attempt.
4. Directly logs the event into Cloud Firestore (`block_events` collection).
5. Serves the visual SignalSafe Red Interstitial Warning Page on port 80/8080.
"""

import sys
import os
import csv
import socket
import select
import struct
import threading
import json
import urllib.request
from datetime import datetime, timezone
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

DATASET_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "Knowledgebase", "datasets", "url_features_extracted1.csv")
FIRESTORE_PROJECT = "hf2signalsafe"
UPSTREAM_DNS = ("1.1.1.1", 53)
DNS_PORT = 53
HTTP_PORT = 80
FALLBACK_HTTP_PORT = 8080

def get_local_ip():
    """Detects the machine's local IP on the gateway / LAN subnet."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

LOCAL_IP = get_local_ip()
BLOCKED_DOMAINS = set()
BLOCKED_ROOTS = set()

def load_dataset():
    global BLOCKED_DOMAINS, BLOCKED_ROOTS
    print(f"[*] Reading dataset from: {DATASET_PATH}")
    if not os.path.exists(DATASET_PATH):
        print(f"[!] Warning: Dataset file not found at {DATASET_PATH}")
        return

    count = 0
    with open(DATASET_PATH, 'r', encoding='utf-8', errors='ignore') as f:
        reader = csv.reader(f)
        try:
            next(reader) # skip header
        except StopIteration:
            return

        for row in reader:
            # ClassLabel 0 is Phishing
            if len(row) >= 18 and row[-1].strip() == '0':
                raw_url = row[0].strip()
                if not raw_url.startswith(('http://', 'https://')):
                    raw_url = 'http://' + raw_url
                try:
                    host = urlparse(raw_url).netloc.split(':')[0].lower().strip()
                    if host:
                        BLOCKED_DOMAINS.add(host)
                        parts = host.split('.')
                        if len(parts) >= 2:
                            root = '.'.join(parts[-2:])
                            BLOCKED_ROOTS.add(root)
                        count += 1
                except Exception:
                    pass

    print(f"[✓] Successfully loaded {count:,} phishing URLs ({len(BLOCKED_DOMAINS):,} unique domains) into memory!")

def is_domain_blocked(domain):
    domain = domain.lower().strip()
    if domain in BLOCKED_DOMAINS:
        return True
    parts = domain.split('.')
    if len(parts) >= 2:
        root = '.'.join(parts[-2:])
        if root in BLOCKED_DOMAINS or root in BLOCKED_ROOTS:
            return True
    return False

def log_event_to_firestore(domain, client_ip, user_agent="Campus-WiFi Client (DNS Sinkhole Intercept)"):
    """Dispatches threat block event directly to Cloud Firestore REST API."""
    def _worker():
        url = f"https://firestore.googleapis.com/v1/projects/{FIRESTORE_PROJECT}/databases/(default)/documents/block_events"
        payload = {
            "fields": {
                "domain": {"stringValue": domain},
                "clientIp": {"stringValue": client_ip},
                "userAgent": {"stringValue": user_agent},
                "createdAt": {"stringValue": datetime.now(timezone.utc).isoformat()}
            }
        }
        try:
            data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
            with urllib.request.urlopen(req, timeout=4) as res:
                if res.status in (200, 204):
                    print(f"[✓ Firestore] Logged threat event: {domain} ({client_ip}) -> UI Live Feed")
        except Exception as e:
            print(f"[!] Firestore REST notice: {e}")

    threading.Thread(target=_worker, daemon=True).start()

# ─── DNS SINKHOLE ENGINE ──────────────────────────────────────────────────────

def parse_dns_qname(data, offset=12):
    """Extracts domain name from raw DNS packet."""
    labels = []
    while True:
        length = data[offset]
        if length == 0:
            offset += 1
            break
        offset += 1
        labels.append(data[offset:offset+length].decode('ascii', errors='ignore'))
        offset += length
    return '.'.join(labels), offset

def build_dns_sinkhole_response(req_data, target_ip):
    """Crafts DNS response pointing blocked domain to our Interstitial server."""
    tx_id = req_data[:2]
    flags = b'\x81\x80' # Standard query response, No error
    qdcount = req_data[4:6]
    ancount = b'\x00\x01' # 1 answer
    nscount = b'\x00\x00'
    arcount = b'\x00\x00'

    header = tx_id + flags + qdcount + ancount + nscount + arcount
    
    # Extract Question Section
    domain, offset = parse_dns_qname(req_data, 12)
    qtype_qclass = req_data[offset:offset+4]
    question = req_data[12:offset+4]

    # Answer Section (Pointer to question name: 0xC00C, Type A=1, Class IN=1, TTL 60s, DataLen 4, IP)
    ip_parts = [int(p) for p in target_ip.split('.')]
    rdata = bytes(ip_parts)
    answer = b'\xc0\x0c\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04' + rdata

    return header + question + answer

def run_dns_server():
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(('0.0.0.0', DNS_PORT))
        print(f"[✓ DNS Sinkhole] Listening on UDP port {DNS_PORT} (Local Gateway: {LOCAL_IP})")
    except Exception as e:
        print(f"[!] Could not bind port {DNS_PORT} (Run terminal as Administrator): {e}")
        return

    upstream_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    upstream_sock.settimeout(2.0)

    while True:
        try:
            data, client_addr = sock.recvfrom(1024)
            if len(data) < 12:
                continue

            client_ip = client_addr[0]
            try:
                domain, _ = parse_dns_qname(data, 12)
            except Exception:
                continue

            if is_domain_blocked(domain):
                print(f"[🚨 BLOCKED] Device: {client_ip} attempted to access dataset threat: {domain}")
                resp = build_dns_sinkhole_response(data, LOCAL_IP)
                sock.sendto(resp, client_addr)
                log_event_to_firestore(domain, client_ip, f"Campus Device ({client_ip}) via DNS Sinkhole")
            else:
                # Forward to real upstream DNS (1.1.1.1) so YouTube, Google, etc. work seamlessly
                try:
                    upstream_sock.sendto(data, UPSTREAM_DNS)
                    upstream_data, _ = upstream_sock.recvfrom(2048)
                    sock.sendto(upstream_data, client_addr)
                except Exception:
                    pass
        except Exception as e:
            pass

# ─── HTTP INTERSTITIAL BLOCK PAGE SERVER ─────────────────────────────────────

INTERSTITIAL_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>SignalSafe — Malicious Threat Blocked</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      background-color: #0b0f19;
      color: #e2e8f0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
    }
    .card {
      background: #111827;
      border: 2px solid #ef4444;
      border-radius: 16px;
      max-width: 520px;
      width: 100%;
      padding: 32px;
      box-shadow: 0 0 35px rgba(239, 68, 68, 0.25);
      text-align: center;
    }
    .shield-icon {
      font-size: 54px;
      color: #ef4444;
      margin-bottom: 12px;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0% { transform: scale(1); }
      50% { transform: scale(1.08); }
      100% { transform: scale(1); }
    }
    h1 {
      color: #ef4444;
      font-size: 20px;
      font-weight: 800;
      letter-spacing: 1px;
      margin: 0 0 10px 0;
    }
    .target-domain {
      background: #1f2937;
      color: #06b6d4;
      font-family: monospace;
      padding: 10px 14px;
      border-radius: 8px;
      font-size: 15px;
      font-weight: 700;
      word-break: break-all;
      margin: 16px 0;
      border: 1px solid #374151;
    }
    p {
      color: #94a3b8;
      font-size: 13px;
      line-height: 1.5;
      margin: 8px 0;
    }
    .badge-bar {
      display: flex;
      justify-content: center;
      gap: 10px;
      margin-top: 18px;
    }
    .badge {
      background: rgba(239, 68, 68, 0.15);
      color: #ef4444;
      border: 1px solid rgba(239, 68, 68, 0.4);
      padding: 5px 12px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 800;
    }
    .footer {
      margin-top: 24px;
      font-size: 11px;
      color: #64748b;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="shield-icon">⚠️</div>
    <h1>CAMPUS ACCESS RESTRICTED</h1>
    <p>SignalSafe Network Security has intercepted and blocked an attempt to visit a verified malicious destination:</p>
    
    <div class="target-domain">%(domain)s</div>

    <p><strong>Client IP:</strong> %(client_ip)s<br>
    <strong>Policy Action:</strong> Blocked by Mendeley LegitPhish Threat Feed<br>
    <strong>Notice:</strong> This incident has been logged live to the IT SecOps Dashboard.</p>

    <div class="badge-bar">
      <span class="badge">MALICIOUS PHISHING SINKHOLE</span>
      <span class="badge">INCIDENT RECORDED</span>
    </div>

    <div class="footer">
      SignalSafe Campus Network Defense &bull; Powered by Deep Learning Threat Classifier
    </div>
  </div>
</body>
</html>
"""

class InterstitialHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        client_ip = self.client_address[0]
        host = self.headers.get('Host', 'Blocked Domain').split(':')[0]
        user_agent = self.headers.get('User-Agent', 'Unknown Browser')

        # Log to Firestore
        log_event_to_firestore(host, client_ip, user_agent)

        content = INTERSTITIAL_HTML % {"domain": host, "client_ip": client_ip}
        body = content.encode('utf-8')

        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass # suppress default server logging

def run_http_server():
    server = None
    for port in (HTTP_PORT, FALLBACK_HTTP_PORT):
        try:
            server = HTTPServer(('0.0.0.0', port), InterstitialHandler)
            print(f"[✓ HTTP Interstitial] Listening on http://0.0.0.0:{port}")
            break
        except Exception:
            continue

    if server:
        server.serve_forever()
    else:
        print("[!] Could not bind HTTP ports (Try running as Administrator)")

def main():
    print("=" * 72)
    print("🛡️   SIGNALSAFE CAMPUS EDGE GATEWAY & DATASET SINKHOLE")
    print("=" * 72)
    load_dataset()
    print("-" * 72)
    print(f"[*] Gateway Local IP:   {LOCAL_IP}")
    print(f"[*] To route VPN clients: Configure DNS in client profile to:")
    print(f"    {LOCAL_IP} or WireGuard gateway subnet")
    print("=" * 72)

    # Start DNS server thread
    dns_thread = threading.Thread(target=run_dns_server, daemon=True)
    dns_thread.start()

    # Start HTTP Interstitial server
    run_http_server()

if __name__ == "__main__":
    main()
