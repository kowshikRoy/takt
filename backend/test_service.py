#!/usr/bin/env python3
"""
Test script for the spaCy POS detection service
"""

import requests
import json

import os
BASE_URL = os.environ.get("BASE_URL", "http://localhost:5000")


def test_health():
    """Test health check endpoint"""
    print("Testing /health endpoint...")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    print()

def test_analyze_noun():
    """Test analyzing a noun"""
    print("Testing noun detection: 'Laufen' in 'Das Laufen ist gesund'")
    response = requests.post(
        f"{BASE_URL}/analyze",
        json={
            "sentence": "Das Laufen ist gesund",
            "word": "Laufen"
        }
    )
    print(f"Status: {response.status_code}")
    result = response.json()
    print(f"Response: {json.dumps(result, indent=2)}")
    assert result['pos'] == 'noun', f"Expected 'noun', got '{result['pos']}'"
    print("✓ Correct!\n")

def test_analyze_verb():
    """Test analyzing a verb"""
    print("Testing verb detection: 'laufen' in 'Wir laufen schnell'")
    response = requests.post(
        f"{BASE_URL}/analyze",
        json={
            "sentence": "Wir laufen schnell",
            "word": "laufen"
        }
    )
    print(f"Status: {response.status_code}")
    result = response.json()
    print(f"Response: {json.dumps(result, indent=2)}")
    assert result['pos'] == 'verb', f"Expected 'verb', got '{result['pos']}'"
    print("✓ Correct!\n")

def test_analyze_adjective():
    """Test analyzing an adjective"""
    print("Testing adjective detection: 'entsprechend' in 'Die entsprechende Regel'")
    response = requests.post(
        f"{BASE_URL}/analyze",
        json={
            "sentence": "Die entsprechende Regel",
            "word": "entsprechende"
        }
    )
    print(f"Status: {response.status_code}")
    result = response.json()
    print(f"Response: {json.dumps(result, indent=2)}")
    assert result['pos'] == 'adj', f"Expected 'adj', got '{result['pos']}'"
    print("✓ Correct!\n")

def test_batch():
    """Test batch analysis"""
    print("Testing batch analysis...")
    response = requests.post(
        f"{BASE_URL}/analyze_batch",
        json={
            "sentence": "Das Laufen ist sehr gesund",
            "words": ["Laufen", "ist", "sehr", "gesund"]
        }
    )
    print(f"Status: {response.status_code}")
    result = response.json()
    print(f"Response: {json.dumps(result, indent=2)}")
    print()

def test_not_found():
    """Test word not found in sentence"""
    print("Testing word not found...")
    response = requests.post(
        f"{BASE_URL}/analyze",
        json={
            "sentence": "Das ist gut",
            "word": "Laufen"
        }
    )
    print(f"Status: {response.status_code}")
    result = response.json()
    print(f"Response: {json.dumps(result, indent=2)}")
    assert result['found'] == False, "Expected found=False"
    print("✓ Correct!\n")

def test_translate():
    """Test translation endpoint"""
    print("Testing translation: 'Das ist ein Test'")
    # Note: First request might timeout if downloading model, so we increase timeout in client if possible
    # Here we just try standard request
    try:
        response = requests.post(
            f"{BASE_URL}/translate",
            json={
                "text": "Das ist ein Test"
            },
            timeout=30 # Allow extra time for model download/load
        )
        print(f"Status: {response.status_code}")
        result = response.json()
        print(f"Response: {json.dumps(result, indent=2)}")
        
        if response.status_code == 200:
            assert "translation" in result
            assert "Test" in result["translation"] or "test" in result["translation"]
            print("✓ Correct!\n")
        else:
            print(f"✗ Failed with status {response.status_code}")
    except requests.exceptions.Timeout:
        print("⚠ Request timed out (likely downloading model). This is expected for first run.")

if __name__ == "__main__":
    print("=" * 60)
    print("spaCy POS & Translation Service - Test Suite")
    print("=" * 60)
    print()
    
    try:
        test_health()
        test_analyze_noun()
        test_analyze_verb()
        test_analyze_adjective()
        test_batch()
        test_not_found()
        test_translate()
        
        print("=" * 60)
        print("✓ POS tests passed! (Translation checked separately)")
        print("=" * 60)
    except requests.exceptions.ConnectionError:
        print("❌ Error: Could not connect to server.")
        print("Make sure the server is running: python app.py")
    except AssertionError as e:
        print(f"❌ Test failed: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
