import sqlite3
import json

db_path = 'assets/german_dictionary_v13.db'

def verify_mann():
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    word_query = "SELECT id, word FROM words WHERE word = 'Mann'"
    cursor.execute(word_query)
    res = cursor.fetchone()
    if not res:
        print("Mann not found")
        return
        
    word_id = res[0]
    print(f"Checking forms for {res[1]} (ID: {word_id})...")
    
    query = """
        SELECT f.form, t.tags 
        FROM forms f
        JOIN tags t ON f.tag_id = t.id
        WHERE f.word_id = ?
    """
    cursor.execute(query, (word_id,))
    rows = cursor.fetchall()
    
    print(f"Found {len(rows)} forms:")
    for r in rows:
        print(f"  - {r[0]} {r[1]}")

    conn.close()

if __name__ == "__main__":
    verify_mann()
