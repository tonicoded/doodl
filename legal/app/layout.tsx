import type { Metadata } from "next";
import "./globals.css";
import { Footer } from "../components/Footer";

export const metadata: Metadata = {
  title: {
    default: "DOODL. — Send doodles to friends",
    template: "%s — DOODL."
  },
  description: "Send doodles to friends like snaps.",
  metadataBase: new URL("https://doodl.app"),
  openGraph: {
    title: "DOODL.",
    description: "Send doodles to friends like snaps.",
    type: "website"
  }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="stage">
          <div className="frame">
            <div className="frameInner">
              <div className="frameScroll">{children}</div>
              <Footer />
            </div>
          </div>
        </div>
      </body>
    </html>
  );
}
