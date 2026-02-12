import Image from "next/image";
import Link from "next/link";

export function Logo() {
  return (
    <Link href="/" aria-label="DOODL home" style={{ display: "inline-flex", alignItems: "center", gap: 10 }}>
      <Image src="/logo.png" alt="DOODL." width={40} height={40} priority />
      <span style={{ fontWeight: 900, letterSpacing: "-0.02em" }}>DOODL.</span>
    </Link>
  );
}

