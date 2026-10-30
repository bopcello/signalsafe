import 'dart:math';

/// SignalSafe URL Feature Extractor
/// Extracts the 16 lexical and structural features from raw URLs identically
/// to the Mendeley LegitPhish dataset feature engineering pipeline.
class FeatureExtractor {
  static const List<String> featureNames = [
    'url_length',
    'has_ip_address',
    'dot_count',
    'https_flag',
    'url_entropy',
    'token_count',
    'subdomain_count',
    'query_param_count',
    'tld_length',
    'path_length',
    'has_hyphen_in_domain',
    'number_of_digits',
    'tld_popularity',
    'suspicious_file_extension',
    'domain_name_length',
    'percentage_numeric_chars',
  ];

  static final RegExp _ipRegex = RegExp(r'^(?:\d{1,3}\.){3}\d{1,3}$');
  static final RegExp _digitRegex = RegExp(r'\d');
  static final RegExp _tokenSplitRegex = RegExp(r'[/.]');
  static final Set<String> _popularTlds = {'com', 'org', 'net'};
  static final Set<String> _suspiciousExtensions = {
    'exe',
    'bin',
    'apk',
    'zip',
    'cmd',
    'js',
    '1exe',
    'scr',
    'bat',
    'vbs',
  };

  /// Extracts the 16 features as a keyed `Map<String, double>`
  static Map<String, double> extractFeaturesMap(String rawUrl) {
    final vector = extractFeaturesVector(rawUrl);
    final map = <String, double>{};
    for (int i = 0; i < featureNames.length; i++) {
      map[featureNames[i]] = vector[i];
    }
    return map;
  }

  /// Extracts the 16 features as an ordered `List<double>`
  static List<double> extractFeaturesVector(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      return List<double>.filled(16, 0.0);
    }

    final fullUrl = (url.contains('://')) ? url : 'http://$url';
    Uri? parsed;
    try {
      parsed = Uri.parse(fullUrl);
    } catch (_) {
      parsed = null;
    }

    final rawHost = parsed?.host ?? '';
    final hostOnly = rawHost.contains(':') ? rawHost.split(':').first : rawHost;

    // 1. url_length
    final double urlLength = url.length.toDouble();

    // 2. has_ip_address
    final bool isIp = _ipRegex.hasMatch(hostOnly);
    final double hasIpAddress = isIp ? 1.0 : 0.0;

    // 3. dot_count
    final double dotCount = '.'.allMatches(url).length.toDouble();

    // 4. https_flag
    final double httpsFlag = url.toLowerCase().startsWith('https') ? 1.0 : 0.0;

    // 5. url_entropy (Shannon Entropy base 2)
    final double urlEntropy = _calculateShannonEntropy(url);

    // 6. token_count (split on / and .)
    final double tokenCount = url.split(_tokenSplitRegex).length.toDouble();

    // Host parts
    final List<String> hostParts = hostOnly.split('.');

    // 7. subdomain_count
    final double subdomainCount = isIp
        ? 2.0
        : (hostParts.length > 2 ? (hostParts.length - 2).toDouble() : 0.0);

    // 8. query_param_count
    final double queryParamCount;
    if (parsed != null && parsed.hasQuery && parsed.query.isNotEmpty) {
      queryParamCount = parsed.query.split('&').length.toDouble();
    } else {
      queryParamCount = 1.0;
    }

    // 9. tld_length
    final double tldLength;
    if (isIp) {
      tldLength = 9.0;
    } else if (hostParts.length >= 2) {
      tldLength = hostParts.last.length.toDouble();
    } else {
      tldLength = 0.0;
    }

    // 10. path_length
    final double pathLength = parsed != null ? parsed.path.length.toDouble() : 0.0;

    // 11. has_hyphen_in_domain
    final double hasHyphenInDomain = hostOnly.contains('-') ? 1.0 : 0.0;

    // 12. number_of_digits
    final int digits = _digitRegex.allMatches(url).length;
    final double numberOfDigits = digits.toDouble();

    // 13. tld_popularity
    final String tld = hostParts.length >= 2 ? hostParts.last.toLowerCase() : '';
    final double tldPopularity = (!isIp && _popularTlds.contains(tld)) ? 1.0 : 0.0;

    // 14. suspicious_file_extension
    final String cleanPath = parsed?.path.toLowerCase() ?? '';
    bool hasSuspiciousExt = false;
    for (final ext in _suspiciousExtensions) {
      if (cleanPath.endsWith('.$ext')) {
        hasSuspiciousExt = true;
        break;
      }
    }
    final double suspiciousFileExtension = hasSuspiciousExt ? 1.0 : 0.0;

    // 15. domain_name_length
    final double domainNameLength;
    if (isIp) {
      domainNameLength = 3.0;
    } else if (hostParts.length >= 2) {
      domainNameLength = hostParts[hostParts.length - 2].length.toDouble();
    } else {
      domainNameLength = hostOnly.length.toDouble();
    }

    // 16. percentage_numeric_chars
    final double percentageNumericChars =
        urlLength > 0 ? (numberOfDigits / urlLength) * 100.0 : 0.0;

    return [
      urlLength,
      hasIpAddress,
      dotCount,
      httpsFlag,
      urlEntropy,
      tokenCount,
      subdomainCount,
      queryParamCount,
      tldLength,
      pathLength,
      hasHyphenInDomain,
      numberOfDigits,
      tldPopularity,
      suspiciousFileExtension,
      domainNameLength,
      percentageNumericChars,
    ];
  }

  static double _calculateShannonEntropy(String s) {
    if (s.isEmpty) return 0.0;
    final Map<int, int> charCounts = {};
    for (int i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      charCounts[code] = (charCounts[code] ?? 0) + 1;
    }

    double entropy = 0.0;
    final double len = s.length.toDouble();
    const double ln2 = 0.6931471805599453; // ln(2)

    for (final count in charCounts.values) {
      final double p = count / len;
      entropy -= p * (log(p) / ln2);
    }
    return entropy;
  }
}
