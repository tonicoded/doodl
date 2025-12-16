import Link from "next/link";

export function Footer() {
  return (
    <footer className="footer">
      <div>© {new Date().getFullYear()} DOODL.</div>
      <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
        <Link href="/privacy/">Privacy</Link>
        <Link href="/terms/">Terms</Link>
        <a href="mailto:anthonyvvza@gmail.com">anthonyvvza@gmail.com</a>
      </div>
    </footer>
  );
}

