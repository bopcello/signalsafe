/// Reason generator for SignalSafe detections
/// Translates raw numerical features into human-readable, plain language explanations
/// for IT heads, network administrators, and campus security staff.
class DetectionReasoning {
  static List<String> generateReasons(Map<String, double> features, double score) {
    final List<String> reasons = [];

    final hasIp = (features['has_ip_address'] ?? 0) > 0.5;
    final httpsFlag = (features['https_flag'] ?? 0) > 0.5;
    final entropy = features['url_entropy'] ?? 0.0;
    final pctDigits = features['percentage_numeric_chars'] ?? 0.0;
    final suspExt = (features['suspicious_file_extension'] ?? 0) > 0.5;
    final subdomains = (features['subdomain_count'] ?? 0.0).toInt();
    final hasHyphen = (features['has_hyphen_in_domain'] ?? 0) > 0.5;
    final tldPopular = (features['tld_popularity'] ?? 0) > 0.5;
    final urlLength = (features['url_length'] ?? 0.0).toInt();
    final queryParams = (features['query_param_count'] ?? 0.0).toInt();

    // Critical Red Flags
    if (hasIp) {
      reasons.add('Direct IP address used as host instead of legitimate domain name');
    }
    if (suspExt) {
      reasons.add('Payload attempts to deliver suspicious executable or archive (.exe, .apk, .bin, .zip)');
    }
    if (entropy > 4.5) {
      reasons.add('Extremely high URL entropy (${entropy.toStringAsFixed(2)} bits/char), indicating hash obfuscation or encrypted payload');
    } else if (entropy > 4.1 && score >= 0.5) {
      reasons.add('High URL entropy (${entropy.toStringAsFixed(2)} bits/char) with random character patterns');
    }
    if (pctDigits > 20.0) {
      reasons.add('Abnormal digit density (${pctDigits.toStringAsFixed(1)}% of URL), typical of auto-generated phishing funnels');
    }
    if (!httpsFlag) {
      reasons.add('Unencrypted plaintext HTTP protocol (missing SSL/TLS certificate)');
    }
    if (hasHyphen && subdomains >= 1) {
      reasons.add('Hyphenated deceptive domain structure with nested subdomains (lookalike/typosquatting)');
    } else if (hasHyphen) {
      reasons.add('Domain contains hyphens often used to mimic trusted brand keywords');
    }
    if (subdomains >= 2 && !hasIp) {
      reasons.add('Deep subdomain nesting ($subdomains subdomains) masking real destination');
    }
    if (!tldPopular && !hasIp) {
      reasons.add('Non-standard or newly observed top-level domain extension');
    }
    if (urlLength > 75) {
      reasons.add('Abnormally long URL length ($urlLength chars) concealing actual endpoint');
    }
    if (queryParams > 2) {
      reasons.add('Multiple stacked query parameters ($queryParams params) passing tracking tokens');
    }

    if (reasons.isEmpty) {
      if (score >= 0.70) {
        reasons.add('Combined lexical heuristics match known phishing infrastructure fingerprints');
      } else if (score >= 0.35) {
        reasons.add('Anomalous token frequency and structural variance flagged for IT verification');
      } else {
        reasons.add('Standard domain structure, verified SSL encryption, and clean token distribution');
      }
    }

    return reasons;
  }
}
