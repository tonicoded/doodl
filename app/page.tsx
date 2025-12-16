export default function Page() {
  const appStoreUrl = "https://apps.apple.com/app/idYOUR_APP_ID";
  const googlePlayUrl = "https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME";

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
