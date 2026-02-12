import Link from "next/link";

export const metadata = {
  title: "Support"
};

export default function SupportPage() {
  return (
    <main className="doc">
      <div className="brand" style={{ marginTop: 6 }}>
        <img src="/logo.png" alt="DOODL." width={110} height={110} />
      </div>

      <article className="sheet supportSheet">
        <div className="sheetHeaderRow">
          <Link className="backLink" href="/">
            ← Home
          </Link>
        </div>

        <h1 className="supportTitle">Support</h1>
        <p className="supportText">For help, please email:</p>
        <a className="supportEmail" href="mailto:anthonyvvza@gmail.com">
          anthonyvvza@gmail.com
        </a>
        <p className="supportText">We typically respond within 24 hours during business days.</p>
      </article>
    </main>
  );
}

