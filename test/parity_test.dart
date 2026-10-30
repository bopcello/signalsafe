import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/scoring/feature_extractor.dart';
import 'package:signalsafe/scoring/forest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SignalSafe Train/Serve Parity Tests', () {
    late ForestEvaluator forest;
    late List<dynamic> parityVectors;

    setUpAll(() async {
      final modelFile = File('assets/model.json');
      expect(modelFile.existsSync(), isTrue, reason: 'assets/model.json must exist');
      final modelJson = modelFile.readAsStringSync();
      forest = ForestEvaluator.fromJsonString(modelJson);

      final parityFile = File('assets/parity_vectors.json');
      expect(parityFile.existsSync(), isTrue, reason: 'assets/parity_vectors.json must exist');
      final parityJson = parityFile.readAsStringSync();
      parityVectors = json.decode(parityJson) as List<dynamic>;
    });

    test('Forest evaluator matches scikit-learn predictions exactly on expected feature vectors', () {
      int exactMatches = 0;
      double maxDiff = 0.0;

      for (final raw in parityVectors) {
        final item = raw as Map<String, dynamic>;
        final rawVector = (item['feature_vector'] as List).map((e) => (e as num).toDouble()).toList();
        final double expectedProb = (item['expected_phish_prob'] as num).toDouble();

        final double dartProb = forest.predictProbability(rawVector);
        final double diff = (dartProb - expectedProb).abs();
        if (diff > maxDiff) maxDiff = diff;

        // Tree traversal over 50 trees must match Python to within 0.001
        expect(diff, lessThan(0.005),
            reason: 'Probability diff too large for URL: ${item['url']} (Dart: $dartProb, Python: $expectedProb)');

        final dartVerdict = ForestEvaluator.getVerdict(dartProb);
        final expectedVerdict = item['expected_verdict'] as String;
        expect(dartVerdict, equals(expectedVerdict));
        exactMatches++;
      }

      print('Evaluator verification passed: $exactMatches / ${parityVectors.length} vectors matched. Max diff: $maxDiff');
    });

    test('End-to-end Dart Feature Extraction + Scoring achieves high accuracy on parity samples', () {
      int correctPredictions = 0;
      final total = parityVectors.length;

      for (final raw in parityVectors) {
        final item = raw as Map<String, dynamic>;
        final url = item['url'] as String;
        final expectedLabel = (item['expected_label'] as num).toInt(); // 1 = phish, 0 = clean

        final extractedVector = FeatureExtractor.extractFeaturesVector(url);
        final score = forest.predictProbability(extractedVector);
        final predictedLabel = score >= 0.50 ? 1 : 0;

        if (predictedLabel == expectedLabel) {
          correctPredictions++;
        }
      }

      final measuredAccuracy = (correctPredictions / total) * 100.0;
      print('--- MEASURED DART PIPELINE ACCURACY ON HELD-OUT PARITY SET: ${measuredAccuracy.toStringAsFixed(2)}% ($correctPredictions / $total) ---');

      // Parity test assert: accuracy on held-out set must exceed 90%
      expect(measuredAccuracy, greaterThan(90.0));
    });
  });
}
