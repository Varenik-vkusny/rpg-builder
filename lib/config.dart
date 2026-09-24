// Адрес проекта Supabase и публичный ключ. Ключ публичный по замыслу Supabase:
// доступ к данным ограничивает RLS, а не он. Секретные ключи сюда не кладутся.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://YOUR-PROJECT-REF.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_YOUR_KEY',
);
