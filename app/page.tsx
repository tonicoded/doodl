import StoreBadges from "../components/StoreBadges";

export default function Page() {
  const appStoreUrl =
    (process.env.NEXT_PUBLIC_APP_STORE_URL as string | undefined) ??
    "https://apps.apple.com/nl/app/doodle-with-friends-doodl/id6756630419";
  const googlePlayUrl =
    (process.env.NEXT_PUBLIC_GOOGLE_PLAY_URL as string | undefined) ??
    "https://play.google.com/store/apps/details?id=com.anthonyverruijt.doodl";
  const betaEmail =
    (process.env.NEXT_PUBLIC_ANDROID_BETA_EMAIL as string | undefined) ?? "anthonyvvza@gmail.com";

  return (
    <main className="home">
      <div className="brand">
        <img src="/logo.png" alt="DOODL." width={124} height={124} />
      </div>

      <h1 className="heroTitle">Send doodles like snaps.</h1>
      <p className="heroSub">
        Add friends by @username, draw something in seconds, tap send — and it shows up instantly. Your widget can always show the
        latest doodl.
      </p>

      <StoreBadges appStoreUrl={appStoreUrl} googlePlayUrl={googlePlayUrl} betaEmail={betaEmail} />
    </main>
  );
}
