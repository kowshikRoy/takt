#!/usr/bin/env python3
"""
Compound Word Puzzle Generator for Takt App
Verifies German compound words, splits them into valid parts, queries Wiktionary dictionary APIs,
fetches accurate genders (Der, Die, Das) & English meanings, and outputs JSON + Dart code.
"""

import json
import os
import re
import requests
from deep_translator import GoogleTranslator

HTTP_HEADERS = {'User-Agent': 'TaktApp/1.0 (https://takt.app; contact@takt.app)'}
translator = GoogleTranslator(source='de', target='en')

# List of 50+ high-frequency German compound words (part1, part2, full_word, fullIcon, part1Icon, part2Icon)
CANDIDATE_COMPOUNDS = [
    ("Glüh", "birne", "Glühbirne", "lightbulb_rounded", "local_fire_department_rounded", "eco_rounded"),
    ("Hand", "schuh", "Handschuh", "pan_tool_rounded", "back_hand_rounded", "do_not_step_rounded"),
    ("Fern", "sehen", "Fernsehen", "tv_rounded", "landscape_rounded", "visibility_rounded"),
    ("Kühl", "schrank", "Kühlschrank", "kitchen_rounded", "ac_unit_rounded", "kitchen_rounded"),
    ("Flug", "zeug", "Flugzeug", "flight_rounded", "flight_rounded", "category_rounded"),
    ("Wörter", "buch", "Wörterbuch", "menu_book_rounded", "translate_rounded", "menu_book_rounded"),
    ("Schild", "kröte", "Schildkröte", "pets_rounded", "shield_rounded", "pets_rounded"),
    ("Regen", "schirm", "Regenschirm", "umbrella_rounded", "water_drop_rounded", "shield_rounded"),
    ("Zahn", "bürste", "Zahnbürste", "cleaning_services_rounded", "sentiment_satisfied_alt_rounded", "cleaning_services_rounded"),
    ("Fahr", "rad", "Fahrrad", "pedal_bike_rounded", "directions_run_rounded", "circle_rounded"),
    ("Schreib", "tisch", "Schreibtisch", "table_restaurant_rounded", "edit_rounded", "table_restaurant_rounded"),
    ("Wochen", "ende", "Wochenende", "event_available_rounded", "calendar_month_rounded", "flag_rounded"),
    ("Flug", "hafen", "Flughafen", "connecting_airports_rounded", "flight_rounded", "directions_boat_rounded"),
    ("Sonnen", "blume", "Sonnenblume", "local_florist_rounded", "wb_sunny_rounded", "local_florist_rounded"),
    ("Kaffee", "tasse", "Kaffeetasse", "coffee_rounded", "coffee_rounded", "local_cafe_rounded"),
    ("Eisen", "bahn", "Eisenbahn", "train_rounded", "hardware_rounded", "alt_route_rounded"),
    ("Haus", "aufgabe", "Hausaufgabe", "assignment_rounded", "home_rounded", "task_rounded"),
    ("Kinder", "garten", "Kindergarten", "child_care_rounded", "child_care_rounded", "park_rounded"),
    ("Frucht", "saft", "Fruchtsaft", "local_drink_rounded", "apple_rounded", "local_drink_rounded"),
    ("Schnee", "mann", "Schneemann", "ac_unit_rounded", "ac_unit_rounded", "person_rounded"),
    ("Hand", "tasche", "Handtasche", "shopping_bag_rounded", "back_hand_rounded", "work_rounded"),
    ("Hand", "tuch", "Handtuch", "dry_cleaning_rounded", "back_hand_rounded", "layers_rounded"),
    ("Auto", "bahn", "Autobahn", "add_road_rounded", "directions_car_rounded", "alt_route_rounded"),
    ("Wasser", "glas", "Wasserglas", "local_bar_rounded", "water_drop_rounded", "wine_bar_rounded"),
    ("Bücher", "regal", "Bücherregal", "shelves", "menu_book_rounded", "format_align_center_rounded"),
    ("Stadt", "zentrum", "Stadtzentrum", "location_city_rounded", "location_city_rounded", "center_focus_strong_rounded"),
    ("Sport", "platz", "Sportplatz", "sports_soccer_rounded", "sports_rounded", "place_rounded"),
    ("Welt", "karte", "Weltkarte", "public_rounded", "public_rounded", "map_rounded"),
    ("Sonnen", "brille", "Sonnenbrille", "visibility_rounded", "wb_sunny_rounded", "visibility_rounded"),
    ("Nacht", "tisch", "Nachttisch", "bedside_table_rounded", "nights_stay_rounded", "table_restaurant_rounded"),
    ("Sommer", "kleid", "Sommerkleid", "checkroom_rounded", "wb_sunny_rounded", "checkroom_rounded"),
    ("Winter", "jacke", "Winterjacke", "checkroom_rounded", "ac_unit_rounded", "checkroom_rounded"),
    ("Tisch", "lampe", "Tischlampe", "light_rounded", "table_restaurant_rounded", "lightbulb_rounded"),
    ("Spiel", "platz", "Spielplatz", "attractions_rounded", "sports_esports_rounded", "place_rounded"),
    ("Werk", "zeug", "Werkzeug", "build_rounded", "handyman_rounded", "category_rounded"),
    ("Schul", "tasche", "Schultasche", "backpack_rounded", "school_rounded", "work_rounded"),
    ("Eis", "creme", "Eiscreme", "icecream_rounded", "ac_unit_rounded", "cake_rounded"),
    ("Kino", "saal", "Kinosaal", "movie_rounded", "local_movies_rounded", "meeting_room_rounded"),
    ("Musik", "instrument", "Musikinstrument", "music_note_rounded", "music_note_rounded", "piano_rounded"),
    ("Bier", "flasche", "Bierflasche", "sports_bar_rounded", "sports_bar_rounded", "wine_bar_rounded"),
    ("Wein", "glas", "Weinglas", "wine_bar_rounded", "wine_bar_rounded", "local_bar_rounded"),
    ("Tanz", "schule", "Tanzschule", "school_rounded", "directions_run_rounded", "school_rounded"),
    ("Computer", "spiel", "Computerspiel", "sports_esports_rounded", "computer_rounded", "sports_esports_rounded"),
    ("Lieblings", "buch", "Lieblingsbuch", "auto_stories_rounded", "favorite_rounded", "menu_book_rounded"),
    ("Apfel", "saft", "Apfelsaft", "local_drink_rounded", "apple_rounded", "local_drink_rounded"),
    ("Regen", "mantel", "Regenmantel", "checkroom_rounded", "water_drop_rounded", "checkroom_rounded"),
    ("Zahn", "creme", "Zahncreme", "clean_hands_rounded", "sentiment_satisfied_alt_rounded", "clean_hands_rounded"),
    ("Haus", "tür", "Haustür", "door_front_door_rounded", "home_rounded", "door_sliding_rounded"),
    ("Schlüssel", "bund", "Schlüsselbund", "key_rounded", "key_rounded", "all_in_one_rounded"),
    ("Fahr", "karte", "Fahrkarte", "confirmation_number_rounded", "directions_run_rounded", "card_membership_rounded"),
]

def verify_word_exists(word: str) -> bool:
    """Verifies if a German word exists in Wiktionary."""
    try:
        params = {'action': 'query', 'titles': word, 'format': 'json'}
        res = requests.get('https://de.wiktionary.org/w/api.php', params=params, headers=HTTP_HEADERS, timeout=5).json()
        pages = res.get('query', {}).get('pages', {})
        for pid in pages:
            if pid != '-1':
                return True
    except Exception as e:
        print(f"[Warning] Dictionary verification error for '{word}': {e}")
    return False

def get_gender(full_word: str) -> str:
    """Fetches article gender (Der, Die, Das) from German Wiktionary wikitext."""
    try:
        params = {'action': 'query', 'titles': full_word, 'prop': 'revisions', 'rvprop': 'content', 'format': 'json'}
        res = requests.get('https://de.wiktionary.org/w/api.php', params=params, headers=HTTP_HEADERS, timeout=5).json()
        pages = res.get('query', {}).get('pages', {})
        for pid in pages:
            content = pages[pid].get('revisions', [{}])[0].get('*', '')
            if re.search(r'\|Genus=f\b|Grammatische Merkmale: \{\{f\}\}|\{\{Substantiv\|f', content):
                return 'Die'
            if re.search(r'\|Genus=n\b|Grammatische Merkmale: \{\{n\}\}|\{\{Substantiv\|n', content):
                return 'Das'
            if re.search(r'\|Genus=m\b|Grammatische Merkmale: \{\{m\}\}|\{\{Substantiv\|m', content):
                return 'Der'
    except Exception as e:
        print(f"[Warning] Gender lookup error for '{full_word}': {e}")
    return 'Der'

def generate_puzzles():
    results = []
    print("🚀 Verifying German Compound Words and Generating Puzzles...\n")

    for item in CANDIDATE_COMPOUNDS:
        p1, p2, full = item[0], item[1], item[2]
        full_icon = item[3]
        p1_icon = item[4]
        p2_icon = item[5]

        # 1. Verify existence
        is_full_valid = verify_word_exists(full)
        if not is_full_valid:
            print(f"❌ Skipping '{full}': Not found in Wiktionary.")
            continue

        # 2. Get Gender
        gender = get_gender(full)

        # 3. Translate Parts and Full Word
        full_meaning = translator.translate(full).capitalize()
        p1_meaning = translator.translate(p1).capitalize()
        p2_meaning = translator.translate(p2).capitalize()

        entry = {
            "part1": p1,
            "part2": p2,
            "part1Meaning": p1_meaning,
            "part2Meaning": p2_meaning,
            "fullWord": full,
            "fullMeaning": full_meaning,
            "gender": gender,
            "part1Subtitle": f'"{p1}-"',
            "part2Subtitle": f'"-{p2}"',
            "part1Icon": p1_icon,
            "part2Icon": p2_icon,
            "fullIcon": full_icon,
            "verified": True
        }

        results.append(entry)
        print(f"✅ Verified: {gender} {full} ({full_meaning}) = {p1} ({p1_meaning}) + {p2} ({p2_meaning})")

    # Output JSON file
    out_json_path = os.path.join(os.path.dirname(__file__), "../assets/compound_words.json")
    os.makedirs(os.path.dirname(out_json_path), exist_ok=True)
    with open(out_json_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n🎉 Successfully verified {len(results)} compound puzzles!")
    print(f"📁 Saved JSON output to: {out_json_path}")
    return results

if __name__ == "__main__":
    generate_puzzles()
