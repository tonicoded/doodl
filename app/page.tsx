export default function Page() {
  const appStoreUrl =
    (process.env.NEXT_PUBLIC_APP_STORE_URL as string | undefined) ??
    "https://apps.apple.com/nl/app/doodle-with-friends-doodl/id6756630419";
  const googlePlayUrl = (process.env.NEXT_PUBLIC_GOOGLE_PLAY_URL as string | undefined) ?? "https://doodl-me.com/";

  return (
    <main className="home">
      <div className="brand">
        <img src="/logo.png" alt="DOODL." width={124} height={124} />
      </div>

      <h1 className="heroTitle">Send quick doodles to your friends &amp; family.</h1>
      <p className="heroSub">
        Draw something in seconds, tap send, and it lands in your group’s inbox. Built for small circles — fast, fun, and
        private.
      </p>

      <div className="storeRow" aria-label="Download">
        <a className="storeBadge" href={appStoreUrl} target="_blank" rel="noreferrer">
          <img src="/appstore.svg" alt="Download on the App Store" />
        </a>
        <a className="storeBadge" href={googlePlayUrl} target="_blank" rel="noreferrer">
          <img src="/googleplay.svg" alt="Get it on Google Play" />
        </a>
      </div>
    </main>
  );
}
