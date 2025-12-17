export const SUPABASE_URL = "https://jgunrdhmipqltddbnnyb.supabase.co";
export const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpndW5yZGhtaXBxbHRkZGJubnliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3MjQzMzQsImV4cCI6MjA4MTMwMDMzNH0.AGUY1vCSojY15_8EN5kvdJ2ApX6RDieSQOC90iaTPq8";

export async function submitAnonymousDoodle(shortCode: string, contentBase64: string) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/submit_anonymous_doodle`, {
    method: "POST",
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      p_short_code: shortCode,
      p_content_base64: contentBase64,
    }),
  });

  if (!response.ok) {
    let message = "failed to send";
    try {
      const payload = await response.json();
      if (payload?.message) message = payload.message;
    } catch {}
    throw new Error(message);
  }

  return (await response.json()) as string;
}

