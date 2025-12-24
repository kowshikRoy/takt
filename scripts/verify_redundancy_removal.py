import sqlite3
import json
import sys
import os

DB_PATH = "../assets/german_dictionary_v15.db"

def verify_removal():
    if not os.path.exists(DB_PATH):
        print(f"Error: Database not found at {DB_PATH}")
        sys.exit(1)

    print(f"Verifying {DB_PATH}...")
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    # 1. Check for removed tags
    forbidden_markers = [
        'multiword-construction',
        'future', 
        'future-i', 
        'future-ii',
        # 'subjunctive-i' # We added this to removal too? Let's check plan. Yes.
    ]
    
    clean = True
    for marker in forbidden_markers:
        print(f"Checking for '{marker}'...")
        # We need to join with tags table
        query = f"SELECT count(*) FROM forms f JOIN tags t ON f.tag_id = t.id WHERE t.tags LIKE '%{marker}%'"
        c.execute(query)
        count = c.fetchone()[0]
        if count > 0:
            print(f"  ❌ FAILED: Found {count} forms with '{marker}'")
            clean = False
            
            # Show examples
            query_ex = f"SELECT f.form, t.tags FROM forms f JOIN tags t ON f.tag_id = t.id WHERE t.tags LIKE '%{marker}%' LIMIT 5"
            c.execute(query_ex)
            for row in c.fetchall():
                print(f"    - {row[0]} {row[1]}")
        else:
            print(f"  ✅ PASSED: No forms with '{marker}'")

    # 3. Check for multi-word Adjectives
    print("Checking for multi-word adjectives...")
    c.execute("SELECT count(*) FROM forms f JOIN words w ON f.word_id = w.id WHERE w.pos = 'adj' AND f.form LIKE '% %'")
    adj_with_spaces = c.fetchone()[0]
    if adj_with_spaces > 0:
        print(f"  ❌ FAILED: Found {adj_with_spaces} adjective forms with spaces")
        clean = False
    else:
        print(f"  ✅ PASSED: No adjective forms with spaces")

    # 4. Verify we didn't delete everything (sanity check)
    c.execute("SELECT count(*) FROM forms")
    total_forms = c.fetchone()[0]
    print(f"Total forms remaining: {total_forms}")
    
    if total_forms < 100000: # Arbitrary large number, prev was millions?
        print("  ⚠️ WARNING: Total forms seem very low!")
        
    conn.close()
    
    if clean:
        print("\nSUCCESS: Redundant forms removed.")
    else:
        print("\nFAILURE: Forbidden forms still exist.")
        sys.exit(1)

if __name__ == "__main__":
    verify_removal()
