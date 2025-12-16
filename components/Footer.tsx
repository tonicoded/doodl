import Link from "next/link";

export function Footer() {
  return (
    <footer className="footerBar">
      <div className="footerLinks" aria-label="Footer">
        <Link href="/privacy/">Privacy</Link>
        <Link href="/terms/">Terms</Link>
        <a href="mailto:anthonyvvza@gmail.com">Support</a>
        <span>© DOODL. {new Date().getFullYear()}</span>
      </div>
    </footer>
  );
}
