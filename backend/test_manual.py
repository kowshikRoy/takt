#!/usr/bin/env python3
"""
Quick manual test for the spaCy service
"""

import sys
sys.path.insert(0, '.')

from app import nlp, POS_MAPPING

def test_pos_detection():
    """Test POS detection with sample sentences"""
    
    test_cases = [
        ("Das Laufen ist gesund", "Laufen", "noun"),
        ("Wir laufen schnell", "laufen", "verb"),
        ("Die entsprechende Regel", "entsprechende", "adj"),
        ("Er spricht entsprechend", "entsprechend", "adv"),
    ]
    
    print("=" * 60)
    print("spaCy POS Detection - Manual Test")
    print("=" * 60)
    print()
    
    for sentence, word, expected_pos in test_cases:
        doc = nlp(sentence)
        
        # Find the word
        token = None
        for t in doc:
            if t.text.lower() == word.lower():
                token = t
                break
        
        if token:
            pos_detailed = token.pos_
            pos_simplified = POS_MAPPING.get(pos_detailed, 'other')
            
            status = "✓" if pos_simplified == expected_pos else "✗"
            print(f"{status} Sentence: '{sentence}'")
            print(f"  Word: '{word}' → POS: {pos_simplified} (expected: {expected_pos})")
            print(f"  Detailed: {pos_detailed}, Lemma: {token.lemma_}")
            print()
        else:
            print(f"✗ Word '{word}' not found in '{sentence}'")
            print()
    
    print("=" * 60)

if __name__ == "__main__":
    if nlp is None:
        print("Error: spaCy model not loaded")
        print("Run: python -m spacy download de_core_news_sm")
        sys.exit(1)
    
    test_pos_detection()
