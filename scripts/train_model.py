import os
import json
import math
from collections import Counter
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score, confusion_matrix

def main():
    print("Loading LegitPhish dataset...")
    csv_path = os.path.join("Knowledgebase", "datasets", "url_features_extracted1.csv")
    df = pd.read_csv(csv_path)
    
    # Drop any nulls
    df = df.dropna(subset=['ClassLabel']).copy()
    print(f"Total valid samples: {len(df)}")
    
    feature_names = [
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
        'percentage_numeric_chars'
    ]
    
    X = df[feature_names].values
    # In LegitPhish, 0 is Phishing and 1 is Legitimate.
    # We define target 1 = Phishing (malicious), 0 = Legitimate (clean)
    y = (df['ClassLabel'] == 0.0).astype(int).values
    
    print(f"Malicious (phishing) samples: {sum(y == 1)} ({sum(y == 1)/len(y)*100:.1f}%)")
    print(f"Clean (legitimate) samples: {sum(y == 0)} ({sum(y == 0)/len(y)*100:.1f}%)")
    
    # Stratified Train / Test Split (80 / 20)
    X_train, X_test, y_train, y_test, df_train, df_test = train_test_split(
        X, y, df, test_size=0.20, random_state=42, stratify=y
    )
    
    print(f"Training set: {len(X_train)} samples | Held-out test set: {len(X_test)} samples")
    print("Training Random Forest Classifier (50 trees, max_depth=10)...")
    
    clf = RandomForestClassifier(
        n_estimators=50,
        max_depth=10,
        min_samples_leaf=3,
        random_state=42,
        n_jobs=-1
    )
    clf.fit(X_train, y_train)
    
    # Evaluate on held-out test set
    y_pred = clf.predict(X_test)
    y_prob = clf.predict_proba(X_test)[:, 1]
    
    acc = accuracy_score(y_test, y_pred)
    prec = precision_score(y_test, y_pred)
    rec = recall_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)
    auc = roc_auc_score(y_test, y_prob)
    cm = confusion_matrix(y_test, y_pred).tolist()
    
    print("\n--- MEASURED VALIDATION ACCURACY (HELD-OUT SET) ---")
    print(f"Accuracy:  {acc*100:.2f}%")
    print(f"Precision: {prec*100:.2f}%")
    print(f"Recall:    {rec*100:.2f}%")
    print(f"F1 Score:  {f1*100:.2f}%")
    print(f"ROC-AUC:   {auc:.4f}")
    print(f"Confusion Matrix: {cm}")
    print("---------------------------------------------------\n")
    
    os.makedirs("assets", exist_ok=True)
    
    # Export model.json
    forest_data = {
        "format": "signalsafe_rf_v1",
        "feature_names": feature_names,
        "n_features": len(feature_names),
        "n_classes": 2,
        "n_trees": len(clf.estimators_),
        "metrics": {
            "accuracy": round(float(acc), 4),
            "precision": round(float(prec), 4),
            "recall": round(float(rec), 4),
            "f1": round(float(f1), 4),
            "roc_auc": round(float(auc), 4),
            "total_samples": len(df),
            "train_samples": len(X_train),
            "test_samples": len(X_test),
            "trees": 50,
            "max_depth": 10
        },
        "trees": []
    }
    
    for tree in clf.estimators_:
        t = tree.tree_
        # In scikit-learn, t.value has shape (n_nodes, 1, n_classes)
        # Value is class count or distribution. We normalize to class probabilities [p_clean, p_phish]
        vals = t.value[:, 0, :]
        sums = vals.sum(axis=1, keepdims=True)
        # Avoid division by zero
        sums[sums == 0] = 1.0
        probs = (vals / sums).tolist()
        
        tree_dict = {
            "children_left": t.children_left.tolist(),
            "children_right": t.children_right.tolist(),
            "feature": t.feature.tolist(),
            "threshold": [round(float(x), 6) for x in t.threshold],
            "phish_prob": [round(float(p[1]), 6) for p in probs]
        }
        forest_data["trees"].append(tree_dict)
        
    model_json_path = os.path.join("assets", "model.json")
    with open(model_json_path, "w", encoding="utf-8") as f:
        json.dump(forest_data, f)
    print(f"Saved {model_json_path} ({os.path.getsize(model_json_path) / 1024:.1f} KB)")
    
    # Export tld_popularity.json
    # Build TLD popularity mapping: top popular TLDs in the dataset with tld_popularity == 1
    # Common global TLDs that are considered popular
    popular_tlds = {
        "com": 1, "org": 1, "net": 1, "edu": 1, "gov": 1, "io": 1,
        "co": 1, "info": 1, "online": 1, "site": 1, "xyz": 1, "tech": 1,
        "uk": 1, "de": 1, "in": 1, "jp": 1, "fr": 1, "au": 1, "ca": 1,
        "us": 1, "ru": 1, "br": 1, "it": 1, "nl": 1, "es": 1, "ch": 1
    }
    tld_path = os.path.join("assets", "tld_popularity.json")
    with open(tld_path, "w", encoding="utf-8") as f:
        json.dump(popular_tlds, f, indent=2)
    print(f"Saved {tld_path}")
    
    # Export parity_vectors.json (~200 samples from held-out test set)
    print("Generating parity vectors for Dart verification...")
    # Sample balanced set of 100 phishing and 100 clean from df_test
    test_phish = df_test[df_test['ClassLabel'] == 0.0].sample(n=100, random_state=42)
    test_clean = df_test[df_test['ClassLabel'] == 1.0].sample(n=100, random_state=42)
    sample_df = pd.concat([test_phish, test_clean]).sample(frac=1.0, random_state=42)
    
    parity_list = []
    for _, row in sample_df.iterrows():
        feat_vals = [float(row[f]) for f in feature_names]
        feat_array = np.array([feat_vals])
        pred_prob = float(clf.predict_proba(feat_array)[0][1])
        
        verdict = "malicious" if pred_prob >= 0.70 else ("suspicious" if pred_prob >= 0.35 else "clean")
        
        item = {
            "url": row['URL'],
            "features": {f: float(row[f]) for f in feature_names},
            "feature_vector": feat_vals,
            "expected_phish_prob": round(pred_prob, 6),
            "expected_label": 1 if row['ClassLabel'] == 0.0 else 0, # 1=phish, 0=clean
            "expected_verdict": verdict
        }
        parity_list.append(item)
        
    parity_path = os.path.join("assets", "parity_vectors.json")
    with open(parity_path, "w", encoding="utf-8") as f:
        json.dump(parity_list, f, indent=2)
    print(f"Saved {parity_path} ({len(parity_list)} test vectors)")
    
    print("\n[SUCCESS] Model training and export complete!")

if __name__ == '__main__':
    main()
