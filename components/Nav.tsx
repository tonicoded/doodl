import Link from "next/link";
import { Logo } from "./Logo";

export function Nav() {
  return (
    <header className="nav">
      <Logo />
      <nav className="navLinks" aria-label="Primary">
        <Link className="navLink" href="/#features">
          Features
        </Link>
        <Link className="navLink" href="/privacy/">
          Privacy
        </Link>
        <Link className="navLink" href="/terms/">
          Terms
        </Link>
        <a className="navLink" href="mailto:anthonyvvza@gmail.com">
          Contact
        </a>
      </nav>
    </header>
  );
}

