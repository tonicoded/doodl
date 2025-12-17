import OpenInAppClient from "./ui";
import { isAnonymousLinkEnabled } from "../supabase";

type PageProps = {
  params: { code: string };
};

export default function Page({ params }: PageProps) {
  const code = (params.code ?? "").toLowerCase();
  const isValid = /^[a-f0-9]{10,24}$/.test(code);
  // Note: Supabase check is done server-side in the async wrapper below.

  return (
    <div className="stage">
      <div className="frame">
        <div className="frameInner">
          {!isValid ? (
            <div className="frameScroll">
              <main className="sheet">
                <div className="brand">
                  <img src="/logo.png" alt="DOODL." width={180} height={180} />
                </div>
                <h1 className="heroTitle" style={{ marginTop: 8 }}>
                  Link not found
                </h1>
                <p className="heroSub" style={{ maxWidth: 520 }}>
                  This link looks invalid. Ask them for a fresh link from DOODL. settings.
                </p>
              </main>
            </div>
          ) : (
            <AsyncGate code={code} />
          )}
        </div>
      </div>
    </div>
  );
}

async function AsyncGate({ code }: { code: string }) {
  try {
    const enabled = await isAnonymousLinkEnabled(code);
    if (!enabled) {
      return (
        <div className="frameScroll">
          <main className="sheet">
            <div className="brand">
              <img src="/logo.png" alt="DOODL." width={180} height={180} />
            </div>
            <h1 className="heroTitle" style={{ marginTop: 8 }}>
              Link not found
            </h1>
            <p className="heroSub" style={{ maxWidth: 520 }}>
              This anonymous link is disabled or doesn’t exist. Ask them to enable it in settings.
            </p>
          </main>
        </div>
      );
    }
  } catch {
    // If Supabase is unreachable, still show the opener UI.
  }

  return <OpenInAppClient code={code} />;
}
