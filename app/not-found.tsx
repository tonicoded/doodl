import Link from "next/link";

export default function NotFound() {
  return (
    <main>
      <div className="brand">
        <img src="/logo.png" alt="DOODL." width={72} height={72} />
        <span className="brandName">DOODL.</span>
      </div>

      <h1 className="heroTitle">Page not found</h1>
      <p className="heroSub">That page doesn’t exist.</p>

      <div className="ctaRow">
        <Link className="btn btnPrimary" href="/">
          Go home
        </Link>
      </div>
    </main>
  );
}
