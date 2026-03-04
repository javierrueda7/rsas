Configura variables de entorno (SUPABASE_URL y KEY)

Cuando ejecutes:

flutter run -d chrome --dart-define=SUPABASE_URL=TU_URL --dart-define=SUPABASE_ANON_KEY=TU_KEY


Y para producción (build):

flutter build web --release --dart-define=SUPABASE_URL=TU_URL --dart-define=SUPABASE_ANON_KEY=TU_KEY

10) Build final para publicar (PWA)
flutter build web --release --dart-define=SUPABASE_URL=TU_URL --dart-define=SUPABASE_ANON_KEY=TU_KEY


Te genera la web lista en:
build/web/

Esa carpeta es la que subes a Firebase Hosting / Netlify / Vercel / etc.





Project name: seguimiento-polizas
Database password: bhJ3F4Nd9V73


flutter run -d web-server --web-port=64580 `
  --dart-define=SUPABASE_URL=https://tmuapctazakdecyddelw.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtdWFwY3RhemFrZGVjeWRkZWx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2Mzk3ODgsImV4cCI6MjA4NTIxNTc4OH0.dC28gXPut6VqkYswXlToWoFTJ2LISZBQYHAmyapKlWI


--dart-define

Project URL → SUPABASE_URL
https://tmuapctazakdecyddelw.supabase.co

anon public key → SUPABASE_ANON_KEY
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtdWFwY3RhemFrZGVjeWRkZWx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2Mzk3ODgsImV4cCI6MjA4NTIxNTc4OH0.dC28gXPut6VqkYswXlToWoFTJ2LISZBQYHAmyapKlWI