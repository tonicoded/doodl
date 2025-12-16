import Link from "next/link";
import { Footer } from "../components/Footer";
import { Nav } from "../components/Nav";

export default function Page() {
  return (
    <main className="container">
      <Nav />

      <section className="hero">
        <div className="heroGrid">
          <div>
            <span className="badge">Send doodles. Feel closer.</span>
            <h1 className="h1">
              DOODL. is the easiest way to send quick doodles to your friends &amp; family.
            </h1>
            <p className="sub">
              Draw something in seconds, tap send, and it lands in your group’s inbox. Built for small circles — fast,
              fun, and private by default.
            </p>

            <div className="ctaRow">
              <a className="button buttonPrimary" href="#" aria-disabled="true">
                Coming soon on the App Store
              </a>
              <Link className="button" href="/privacy/">
                Read Privacy Policy
              </Link>
            </div>

            <p style={{ marginTop: 12, color: "rgba(255,255,255,.7)", fontSize: 13 }}>
              Tip: keep groups small — it feels more personal.
            </p>
          </div>

          <div className="card" style={{ padding: 18 }}>
            <h2 style={{ margin: 0, fontSize: 16, letterSpacing: "-0.01em" }}>What you can do</h2>
            <div style={{ height: 10 }} />
            <div style={{ display: "grid", gap: 10 }}>
              <div className="card" style={{ background: "rgba(0,0,0,0.14)" }}>
                <div className="cardTitle">Share</div>
                <div className="cardText">Send a doodle to your group in one tap.</div>
              </div>
              <div className="card" style={{ background: "rgba(0,0,0,0.14)" }}>
                <div className="cardTitle">Inbox</div>
                <div className="cardText">See what your friends drew, with unread counts.</div>
              </div>
              <div className="card" style={{ background: "rgba(0,0,0,0.14)" }}>
                <div className="cardTitle">Streaks</div>
                <div className="cardText">Keep a daily doodle streak with your group.</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="features" className="features" aria-label="Features">
        <div className="card span6">
          <h3 className="cardTitle">Made for small groups</h3>
          <p className="cardText">Create a group with friends or family and keep the vibe close.</p>
        </div>
        <div className="card span6">
          <h3 className="cardTitle">Fast drawing, clean UI</h3>
          <p className="cardText">Pen/marker/pencil tools, colors, sizes — made to feel smooth and satisfying.</p>
        </div>
        <div className="card span4">
          <h3 className="cardTitle">Unread badges</h3>
          <p className="cardText">Like Instagram — instantly see what’s new.</p>
        </div>
        <div className="card span4">
          <h3 className="cardTitle">Online status</h3>
          <p className="cardText">See who’s around (based on recent activity).</p>
        </div>
        <div className="card span4">
          <h3 className="cardTitle">Widget-friendly</h3>
          <p className="cardText">Get quick updates right from your Home Screen.</p>
        </div>
        <div className="card span12">
          <h3 className="cardTitle">Privacy-first by design</h3>
          <p className="cardText">
            We collect only what we need to run the app. Read the <Link href="/privacy/">Privacy Policy</Link> for details.
          </p>
        </div>
      </section>

      <Footer />
    </main>
  );
}

