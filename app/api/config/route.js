export const dynamic = 'force-dynamic';
// Public settings the site reads at startup. All three values are safe to expose.
export async function GET() {
  return Response.json({
    url: process.env.NEXT_PUBLIC_SUPABASE_URL || '',
    key: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '',
    ts: process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY || '',
  });
}
