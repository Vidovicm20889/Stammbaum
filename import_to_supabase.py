import json
from supabase import create_client

SUPABASE_URL = "https://DEIN-PROJEKT.supabase.co"
SUPABASE_KEY = "dein-anon-key"
FAMILIE_ID = "die-familie-id-von-oben"

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

with open("personen.json", "r", encoding="utf-8") as f:
    personen = json.load(f)

externe_id_zu_neuer_id = {}

for p in personen:
    eintrag = {
        "familie_id": FAMILIE_ID,
        "externe_id": p.get("id"),
        "vorname": p.get("vorname", ""),
        "nachname": p.get("nachname", ""),
        "geburtsdatum": p.get("geburtsdatum"),
        "sterbedatum": p.get("sterbedatum"),
        "geschlecht": p.get("geschlecht"),
        "notizen": p.get("notizen"),
        "stammbaum_daten": p
    }
    result = supabase.table("personen").insert(eintrag).execute()
    externe_id_zu_neuer_id[p["id"]] = result.data[0]["id"]
    print(f"Importiert: {p.get('vorname')} {p.get('nachname')}")

with open("id_mapping.json", "w") as f:
    json.dump(externe_id_zu_neuer_id, f, indent=2)

print(f"\nFertig! {len(personen)} Personen importiert.")
print("ID-Mapping in id_mapping.json gespeichert (für Beziehungen-Import).")