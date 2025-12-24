import sqlite3
import json
import collections

db_path = 'assets/german_dictionary_v13.db'

def analyze_adj_tags():
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    print("Fetching tag map...")
    cursor.execute("SELECT id, tags FROM tags")
    tag_map = {row[0]: json.loads(row[1]) for row in cursor.fetchall()}

    print("Counting adjective forms...")
    # Join with words table to filter only adjectives
    query = """
        SELECT f.tag_id, COUNT(*) 
        FROM forms f
        JOIN words w ON f.word_id = w.id
        WHERE w.pos = 'adj'
        GROUP BY f.tag_id
    """
    cursor.execute(query)
    tag_counts = cursor.fetchall()

    tag_content_counts = collections.defaultdict(int)
    individual_tag_counts = collections.defaultdict(int)
    total_adj_forms = 0

    for tag_id, count in tag_counts:
        total_adj_forms += count
        tags_list = tag_map.get(tag_id, [])
        tags_tuple = tuple(sorted(tags_list))
        tag_content_counts[tags_tuple] += count
        
        for t in tags_list:
            individual_tag_counts[t] += count

    print(f"Total Adjective Forms: {total_adj_forms}")

    print("\n--- Top 20 Adjective Tag Sets ---")
    sorted_tag_sets = sorted(tag_content_counts.items(), key=lambda x: x[1], reverse=True)
    for tags, count in sorted_tag_sets[:20]:
        print(f"{count}: {tags}")

    print("\n--- Individual Tag Frequencies (Adjectives) ---")
    sorted_individual = sorted(individual_tag_counts.items(), key=lambda x: x[1], reverse=True)
    for tag, count in sorted_individual:
        print(f"{tag}: {count}")
    
    # Check "predictive" vs others
    print("\n--- Predicative vs Attributive ---")
    cursor.execute("""
        SELECT COUNT(*) FROM forms f 
        JOIN words w ON f.word_id = w.id
        JOIN tags t ON f.tag_id = t.id
        WHERE w.pos = 'adj' AND t.tags LIKE '%predicative%'
    """)
    predicative_count = cursor.fetchone()[0]
    print(f"Predicative forms: {predicative_count}")

    conn.close()

if __name__ == "__main__":
    analyze_adj_tags()
