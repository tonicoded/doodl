import Link from "next/link";

export function Footer() {
  return (
    <footer className="footerBar">
      <div className="footerLinks" aria-label="Footer">
        <Link href="/privacy/">Privacy</Link>
        <Link href="/terms/">Terms</Link>
        <Link href="/support/">Support</Link>
        <span>© DOODL. {new Date().getFullYear()}</span>
      </div>
    </footer>
  );
}
