// Адрес проекта Supabase и публичный ключ. В репозитории их нет: сборка берёт их из .env
// (`--dart-define-from-file=.env`, образец — .env.example). Ключ публичный по замыслу Supabase:
// доступ к данным ограничивает RLS, а не он. Секретные ключи сюда не кладутся.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_KEY');
