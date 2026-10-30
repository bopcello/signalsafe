import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/scoring/forest.dart';
import 'package:signalsafe/services/scoring_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final modelFile = File('assets/model.json');
    ForestEvaluator.fromJsonString(modelFile.readAsStringSync());
  });

  group('ScoringService Whitelist & YouTube Link Tests', () {
    final scoring = ScoringService();

    test('youtu.be video link with tracking query is recognized as Clean', () async {
      const youtubeUrl = 'https://youtu.be/xJomaE58h5I?si=kpceoedHsqZ2AHq_';
      final result = await scoring.scoreURL(youtubeUrl);

      expect(result.verdict, equals('clean'));
      expect(result.score, lessThan(0.10));
      expect(result.domain, equals('youtu.be'));
      expect(result.reasons.first, contains('Verified Global Platform'));
    });

    test('youtube.com full watch link is recognized as Clean', () async {
      const fullYoutube = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final result = await scoring.scoreURL(fullYoutube);

      expect(result.verdict, equals('clean'));
      expect(result.score, lessThan(0.10));
      expect(result.domain, equals('www.youtube.com'));
    });

    test('Real phishing URL is accurately flagged as malicious', () async {
      const phishingUrl = 'https://keraekken-loagginnusa.godaddysites.com/';
      final result = await scoring.scoreURL(phishingUrl);

      expect(result.verdict, equals('malicious'));
      expect(result.score, greaterThan(0.70));
    });
  });
}
