from unittest.mock import MagicMock
import sys

sys.modules['faster_whisper'] = MagicMock()
sys.modules['deep_translator'] = MagicMock()

from main import SubtitleCue, merge_cues_into_sentences, is_sentence_terminal

def test_sentence_terminal_detection():
    assert is_sentence_terminal("Hallo.") is True
    assert is_sentence_terminal("Wie geht es dir?") is True
    assert is_sentence_terminal("Auf Wiedersehen!") is True
    assert is_sentence_terminal("Das ist super…") is True
    assert is_sentence_terminal("Er sagte: \"Ja!\"") is True
    
    # Non-terminals and abbreviations
    assert is_sentence_terminal("Hallo") is False
    assert is_sentence_terminal("Wir haben z.B.") is False
    assert is_sentence_terminal("Dr.") is False
    assert is_sentence_terminal("Heute ist der 1.") is False
    assert is_sentence_terminal("Wenn ich komme,") is False

def test_merge_whisper_fragments():
    cues = [
        SubtitleCue(start=0.0, end=1.5, original="Hallo und herzlich", translated="Hello and warmly"),
        SubtitleCue(start=1.5, end=3.2, original="willkommen zu unserem neuen", translated="welcome to our new"),
        SubtitleCue(start=3.2, end=4.8, original="Video.", translated="video."),
        SubtitleCue(start=5.2, end=7.0, original="Heute lernen wir,", translated="Today we learn,"),
        SubtitleCue(start=7.1, end=9.3, original="wie man auf Deutsch", translated="how to in German"),
        SubtitleCue(start=9.3, end=11.0, original="im Supermarkt einkauft!", translated="shop at the supermarket!"),
    ]
    
    merged = merge_cues_into_sentences(cues)
    
    assert len(merged) == 2
    assert merged[0].start == 0.0
    assert merged[0].end == 4.8
    assert merged[0].original == "Hallo und herzlich willkommen zu unserem neuen Video."
    assert merged[0].translated == "Hello and warmly welcome to our new video."
    
    assert merged[1].start == 5.2
    assert merged[1].end == 11.0
    assert merged[1].original == "Heute lernen wir, wie man auf Deutsch im Supermarkt einkauft!"

def test_abbreviation_not_split():
    cues = [
        SubtitleCue(start=0.0, end=2.0, original="Wir haben viele Optionen, z.B.", translated="We have many options, e.g."),
        SubtitleCue(start=2.1, end=4.0, original="den roten Apfel.", translated="the red apple."),
    ]
    merged = merge_cues_into_sentences(cues)
    assert len(merged) == 1
    assert merged[0].original == "Wir haben viele Optionen, z.B. den roten Apfel."

def test_lowercase_continuation_across_pause():
    cues = [
        SubtitleCue(start=0.0, end=2.0, original="Ich weiß nicht genau", translated=""),
        SubtitleCue(start=2.5, end=4.5, original="ob er heute kommt.", translated=""),
    ]
    merged = merge_cues_into_sentences(cues)
    assert len(merged) == 1
    assert merged[0].original == "Ich weiß nicht genau ob er heute kommt."

def test_already_complete_sentences_remain_separate():
    cues = [
        SubtitleCue(start=0.0, end=2.0, original="Guten Morgen!", translated="Good morning!"),
        SubtitleCue(start=2.5, end=5.0, original="Wie geht es Ihnen?", translated="How are you?"),
    ]
    merged = merge_cues_into_sentences(cues)
    assert len(merged) == 2
    assert merged[0].original == "Guten Morgen!"
    assert merged[1].original == "Wie geht es Ihnen?"

if __name__ == '__main__':
    test_sentence_terminal_detection()
    test_merge_whisper_fragments()
    test_abbreviation_not_split()
    test_lowercase_continuation_across_pause()
    test_already_complete_sentences_remain_separate()
    print("All sentence merging tests passed successfully!")
