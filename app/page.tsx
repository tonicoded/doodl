import Link from "next/link";

export default function Page() {
  return (
    <main>
      <div className="brand">
        <img src="/logo.png" alt="DOODL." width={72} height={72} />
        <span className="brandName">DOODL.</span>
      </div>

      <div className="pillRow" aria-label="Highlights">
        <span className="pill">Send doodles</span>
        <span className="pill">Small groups</span>
        <span className="pill">Private by default</span>
      </div>

      <h1 className="heroTitle">Send quick doodles to your friends &amp; family.</h1>
      <p className="heroSub">
        Draw something in seconds, tap send, and it lands in your group’s inbox. Built for small circles — fast, fun, and
        private.
      </p>

      <div className="ctaRow">
        <a className="btn btnPrimary btnDisabled" href="#" aria-disabled="true">
          Coming soon on the App Store
        </a>
        <Link className="btn btnSecondary" href="/privacy/">
          Privacy
        </Link>
        <Link className="btn btnSecondary" href="/terms/">
          Terms
        </Link>
      </div>

      <p className="hintText">Tip: keep groups small — it feels more personal.</p>
    </main>
  );
}
