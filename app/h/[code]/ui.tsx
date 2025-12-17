"use client";

import { useEffect, useMemo, useState } from "react";

type Props = {
  code: string;
};

export default function OpenInAppClient({ code }: Props) {
  const [didAttemptOpen, setDidAttemptOpen] = useState(false);

  const appStoreUrl =
    (process.env.NEXT_PUBLIC_APP_STORE_URL as string | undefined) ?? "https://doodl-app.vercel.app/";
  const googlePlayUrl =
    (process.env.NEXT_PUBLIC_GOOGLE_PLAY_URL as string | undefined) ?? "https://doodl-app.vercel.app/";

  useEffect(() => {
    if (didAttemptOpen) return;
    setDidAttemptOpen(true);

    const ua = navigator.userAgent ?? "";
    const isAndroid = /Android/i.test(ua);
    const fallbackUrl = isAndroid ? googlePlayUrl : appStoreUrl;
    const deepLinkUrl = `doodl://h/${code}`;

    const timer = window.setTimeout(() => {
      window.location.href = fallbackUrl;
    }, 1400);

    const onVisibilityChange = () => {
      if (document.visibilityState === "hidden") {
        window.clearTimeout(timer);
      }
    };

    document.addEventListener("visibilitychange", onVisibilityChange);

    // Avoid navigating away to a custom scheme (which can show "invalid address" in Safari).
    // Using a hidden iframe keeps the landing page visible, while still triggering the app open.
    const iframe = document.createElement("iframe");
    iframe.style.display = "none";
    iframe.src = deepLinkUrl;
    document.body.appendChild(iframe);

    return () => {
      window.clearTimeout(timer);
      iframe.remove();
      document.removeEventListener("visibilitychange", onVisibilityChange);
    };
  }, [appStoreUrl, code, didAttemptOpen, googlePlayUrl]);

  const deepLinkUrl = useMemo(() => `doodl://h/${code}`, [code]);

  return (
    <div className="anonPage">
      <div className="anonScroll">
        <main className="sheet anonSheet">
          <div className="brand">
            <img src="/logo.png" alt="DOODL." width={150} height={150} />
          </div>

          <h1 className="heroTitle anonTitle">opening DOODL…</h1>
          <p className="heroSub anonSub">If you have the app, you’ll be taken there to draw and send an anonymous doodl.</p>

          <div className="ctaRow" style={{ marginTop: 18 }}>
            <button
              type="button"
              className="btn btnPrimary"
              onClick={() => {
                // User gesture attempt (more reliable than autoplay).
                window.location.href = deepLinkUrl;
              }}
            >
              open DOODL
            </button>
          </div>

          <div className="dividerRow" aria-hidden="true" style={{ marginTop: 18 }}>
            <div className="dividerLine" />
            <div className="dividerText">or</div>
            <div className="dividerLine" />
          </div>

          <div className="storeRow" aria-label="Download" style={{ marginTop: 16 }}>
            <a className="storeBadge" href={appStoreUrl} target="_blank" rel="noreferrer">
              <img src="/appstore.svg" alt="Download on the App Store" />
            </a>
            <a className="storeBadge" href={googlePlayUrl} target="_blank" rel="noreferrer">
              <img src="/googleplay.svg" alt="Get it on Google Play" />
            </a>
          </div>
        </main>
      </div>
    </div>
  );
}
