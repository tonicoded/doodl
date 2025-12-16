import Link from "next/link";
import { Nav } from "../components/Nav";

export default function NotFound() {
  return (
    <main className="container">
      <Nav />
      <section className="hero" style={{ marginTop: 18 }}>
        <h1 className="h1" style={{ fontSize: 42 }}>
          Page not found
        </h1>
        <p className="sub">That page doesn’t exist.</p>
        <div className="ctaRow" style={{ marginTop: 16 }}>
          <Link className="button buttonPrimary" href="/">
            Go home
          </Link>
        </div>
      </section>
    </main>
  );
}

