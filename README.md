# Midnightaffair

Agency-managed introductions site. Visitors chat with no signup.
`public/index.html` is the site, `app/api/config` passes your Supabase settings to it, `supabase/sql/schema.sql` is the database.
With no settings it runs as a browser-only demo (admin PIN in `const PIN`).

## 1. Deploy to Vercel
1. Put this folder on GitHub.
2. Vercel > Add New > Project > import it > Deploy.

## 2. Supabase (the real admin server)
1. supabase.com > New project.
2. SQL Editor > paste and run `supabase/sql/schema.sql`.
3. Authentication > Sign In / Providers > turn on Anonymous sign-ins.
4. Authentication > Users > Add user: your admin email + password. Copy the user ID.
5. SQL Editor: `insert into admins (user_id) values ('PASTE-ID-HERE');`
6. Project Settings > API: copy the Project URL and the anon public key.

## 3. Connect them
Vercel > your project > Settings > Environment Variables, add:
- NEXT_PUBLIC_SUPABASE_URL
- NEXT_PUBLIC_SUPABASE_ANON_KEY
Then Deployments > Redeploy. Admin sign-in is at https://YOUR-SITE/#/admin (email + password).

## 4. Bot check (recommended)
1. Cloudflare dashboard > Turnstile > add a widget for your domain. Copy site key and secret.
2. Supabase > Authentication > Attack Protection > enable CAPTCHA (Turnstile) and paste the secret.
3. Vercel env var NEXT_PUBLIC_TURNSTILE_SITE_KEY = site key. Redeploy.
