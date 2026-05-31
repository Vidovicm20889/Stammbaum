# Stammbaum Vidović — Projektkontext für Claude Code

## Projekt
Interaktive Familienstammbaum-Webapp für die Familie Vidović.
GitHub Pages: vidovicm20889.github.io/Stammbaum/stammbaum.html
Aktuell: Vanilla HTML/CSS/JS, kein Framework, kein Build-Tool.

## Design-Regeln (IMMER einhalten)
- Edles, nobles Design — dunkles Farbschema, Serifenschriften, Gold-Akzente
- Konsistent mit bestehendem Stil (Bild4.jpg als Hintergrundbild auf #baum-container)
- Mobile-first: jede Änderung muss auf Smartphone funktionieren
- Mehrsprachig: DE / SR / EN — Texte nie hardcoden, immer i18n-Objekte verwenden

## Architektur-Regeln
- Keine externen Libraries ohne ausdrückliche Absprache
- Direkte Blutlinie (Tanasije → Simo → Marko) ist immer der zentrale vertikale Hauptstrang
- Rollen-System: Super-Admin / Familien-Admin / Familienmitglied (nur Lesezugriff)
- Familien-Isolation: jede Familie sieht nur eigene Daten (außer Super-Admin)

## Dein Arbeitsablauf (Loop)
Nach JEDER Änderung:
1. Prüfe selbst: Gibt es Seiteneffekte auf andere Komponenten?
2. Prüfe: Hält die Lösung alle Design-Regeln ein?
3. Prüfe: Funktioniert es auf Mobile (< 480px)?
4. Gib Selbsteinschätzung: ✅ alles ok / ⚠️ Kompromiss nötig / ❌ Problem gefunden
5. Schlage den logisch nächsten Schritt vor

## Was noch kommt (Roadmap-Kontext)
- Phase 1: Kostenlos, statisch
- Phase 2: Auth (Supabase), Abo-Modell (Stripe), Familien-Isolation
