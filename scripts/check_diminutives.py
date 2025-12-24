import sqlite3

db_path = 'assets/german_dictionary_v12.db'

def check_diminutives():
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Diminutives to check
    diminutives = ["Männchen", "Männlein", "Häuschen", "Büchlein"]
    
    print("Checking if diminutives exist as main words...")
    for d in diminutives:
        cursor.execute("SELECT id, word FROM words WHERE word = ? COLLATE NOCASE", (d,))
        res = cursor.fetchall()
        if res:
            print(f"✅ {d} exists as a word (ID: {res[0][0]})")
        else:
            print(f"❌ {d} DOES NOT exist as a word")

    conn.close()

if __name__ == "__main__":
    check_diminutives()
