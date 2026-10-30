import 'dart:convert';
import 'package:flutter/services.dart';

class ModelMetrics {
  final double accuracy;
  final double precision;
  final double recall;
  final double f1;
  final double rocAuc;
  final int totalSamples;
  final int trainSamples;
  final int testSamples;
  final int trees;
  final int maxDepth;

  const ModelMetrics({
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1,
    required this.rocAuc,
    required this.totalSamples,
    required this.trainSamples,
    required this.testSamples,
    required this.trees,
    required this.maxDepth,
  });

  factory ModelMetrics.fromJson(Map<String, dynamic> json) {
    return ModelMetrics(
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      precision: (json['precision'] as num?)?.toDouble() ?? 0.0,
      recall: (json['recall'] as num?)?.toDouble() ?? 0.0,
      f1: (json['f1'] as num?)?.toDouble() ?? 0.0,
      rocAuc: (json['roc_auc'] as num?)?.toDouble() ?? 0.0,
      totalSamples: (json['total_samples'] as num?)?.toInt() ?? 0,
      trainSamples: (json['train_samples'] as num?)?.toInt() ?? 0,
      testSamples: (json['test_samples'] as num?)?.toInt() ?? 0,
      trees: (json['trees'] as num?)?.toInt() ?? 50,
      maxDepth: (json['max_depth'] as num?)?.toInt() ?? 10,
    );
  }
}

class CompactTree {
  final List<int> childrenLeft;
  final List<int> childrenRight;
  final List<int> feature;
  final List<double> threshold;
  final List<double> phishProb;

  CompactTree({
    required this.childrenLeft,
    required this.childrenRight,
    required this.feature,
    required this.threshold,
    required this.phishProb,
  });

  factory CompactTree.fromJson(Map<String, dynamic> json) {
    return CompactTree(
      childrenLeft: (json['children_left'] as List).map((e) => (e as num).toInt()).toList(),
      childrenRight: (json['children_right'] as List).map((e) => (e as num).toInt()).toList(),
      feature: (json['feature'] as List).map((e) => (e as num).toInt()).toList(),
      threshold: (json['threshold'] as List).map((e) => (e as num).toDouble()).toList(),
      phishProb: (json['phish_prob'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }

  double predict(List<double> features) {
    int node = 0;
    while (childrenLeft[node] != -1) {
      final int featIdx = feature[node];
      final double val = features[featIdx];
      if (val <= threshold[node]) {
        node = childrenLeft[node];
      } else {
        node = childrenRight[node];
      }
    }
    return phishProb[node];
  }
}

/// SignalSafe Random Forest Evaluator
/// Evaluates the exported 50-tree Random Forest on-device in under 1ms.
class ForestEvaluator {
  final List<CompactTree> trees;
  final List<String> featureNames;
  final ModelMetrics metrics;

  ForestEvaluator({
    required this.trees,
    required this.featureNames,
    required this.metrics,
  });

  static ForestEvaluator? _instance;
  static ForestEvaluator get instance {
    if (_instance == null) {
      throw StateError('ForestEvaluator not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  static Future<ForestEvaluator> initialize({String assetPath = 'assets/model.json'}) async {
    if (_instance != null) return _instance!;
    final jsonStr = await rootBundle.loadString(assetPath);
    _instance = fromJsonString(jsonStr);
    return _instance!;
  }

  static ForestEvaluator fromJsonString(String jsonStr) {
    final Map<String, dynamic> data = json.decode(jsonStr) as Map<String, dynamic>;
    final featureNames = (data['feature_names'] as List).map((e) => e.toString()).toList();
    final metrics = ModelMetrics.fromJson(data['metrics'] as Map<String, dynamic>);
    final rawTrees = data['trees'] as List;
    final trees = rawTrees.map((t) => CompactTree.fromJson(t as Map<String, dynamic>)).toList();

    final evaluator = ForestEvaluator(
      trees: trees,
      featureNames: featureNames,
      metrics: metrics,
    );
    _instance = evaluator;
    return evaluator;
  }

  /// Evaluates features and returns probability of phishing [0.0 - 1.0]
  double predictProbability(List<double> featureVector) {
    if (trees.isEmpty) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < trees.length; i++) {
      sum += trees[i].predict(featureVector);
    }
    final avg = sum / trees.length;
    return avg.clamp(0.0, 1.0);
  }

  /// Classifies score into verdict: malicious, suspicious, or clean
  static String getVerdict(double score) {
    if (score >= 0.70) return 'malicious';
    if (score >= 0.35) return 'suspicious';
    return 'clean';
  }
}
