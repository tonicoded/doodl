import AnonymousDoodleClient from "./ui";

type PageProps = {
  params: { code: string };
};

export default function Page({ params }: PageProps) {
  const code = (params.code ?? "").toLowerCase();
  const isValid = /^[a-f0-9]{10,24}$/.test(code);

  return (
    <div className="stage">
      <div className="frame">
        <div className="frameInner">
          <div className="frameScroll">
            {!isValid ? (
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
            ) : (
              <AnonymousDoodleClient code={code} />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

