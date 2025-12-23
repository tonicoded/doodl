import type { Metadata } from "next";
import "./globals.css";
import { Footer } from "../components/Footer";

export const metadata: Metadata = {
  title: {
    default: "DOODL. — Send doodles to friends",
    template: "%s — DOODL."
  },
  description: "A simple way to send doodles to friends and family in small groups.",
  metadataBase: new URL("https://doodl.app"),
  openGraph: {
    title: "DOODL.",
    description: "Send doodles to friends and family in small groups.",
    type: "website"
  }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="snow" aria-hidden="true" />
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
