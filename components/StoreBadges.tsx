"use client";

import { useState, type CSSProperties, type FormEvent } from "react";

type Props = {
  appStoreUrl: string;
  googlePlayUrl: string;
  betaEmail: string;
  rowStyle?: CSSProperties;
};

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const DEFAULT_SUBJECT = "DOODL Android beta access";

const buildMailtoHref = (address: string, userEmail: string) => {
  const bodyLines = ["Hi! Please add me to the DOODL Android beta."];
  if (userEmail) {
    bodyLines.push(`Google account email: ${userEmail}`);
  }
  const subject = encodeURIComponent(DEFAULT_SUBJECT);
  const body = encodeURIComponent(bodyLines.join("\n"));
  return `mailto:${address}?subject=${subject}&body=${body}`;
};

export default function StoreBadges({ appStoreUrl, googlePlayUrl, betaEmail, rowStyle }: Props) {
  const [isOpen, setIsOpen] = useState(false);
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "error" | "sent">("idle");
  const trimmedEmail = email.trim();
  const canSubmit = trimmedEmail.length > 0;
  const betaEmailAddress = betaEmail || "anthonyvvza@gmail.com";

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!EMAIL_PATTERN.test(trimmedEmail)) {
      setStatus("error");
      return;
    }
    setEmail(trimmedEmail);
    setStatus("sent");
    window.location.href = buildMailtoHref(betaEmailAddress, trimmedEmail);
  };

  return (
    <>
      <div className="storeRow" aria-label="Download" style={rowStyle}>
        <a className="storeBadge" href={appStoreUrl} target="_blank" rel="noreferrer">
          <img src="/appstore.svg" alt="Download on the App Store" />
        </a>
        <button
          className="storeBadge storeBadgeButton"
          type="button"
          onClick={() => {
            setIsOpen(true);
            setStatus("idle");
          }}
        >
          <img src="/googleplay.svg" alt="Get it on Google Play" />
        </button>
      </div>

      {isOpen ? (
        <div
          className="anonModalBackdrop"
          role="dialog"
          aria-modal="true"
          aria-labelledby="android-beta-title"
          onClick={() => setIsOpen(false)}
        >
          <div className="anonModal" onClick={(event) => event.stopPropagation()}>
            <div className="anonModalHeader">
              <div className="anonModalTitle" id="android-beta-title">
                Android beta
              </div>
              <button className="anonModalClose" type="button" onClick={() => setIsOpen(false)} aria-label="Close">
                x
              </button>
            </div>
            <p className="anonModalSub">
              Android is in closed testing. Share your Google account email so we can add you to the beta list.
            </p>

            <form className="betaForm" onSubmit={handleSubmit}>
              <label className="betaLabel" htmlFor="android-beta-email">
                Google account email
              </label>
              <input
                className="betaInput"
                id="android-beta-email"
                type="email"
                inputMode="email"
                autoComplete="email"
                spellCheck={false}
                placeholder="you@gmail.com"
                value={email}
                onChange={(event) => {
                  setEmail(event.target.value);
                  if (status !== "idle") {
                    setStatus("idle");
                  }
                }}
                aria-describedby="android-beta-hint"
                aria-invalid={status === "error"}
                required
                autoFocus
              />
              <p className="betaHint" id="android-beta-hint">
                We only use this to add you to the Android beta.
              </p>
              {status === "error" ? (
                <p className="betaStatus betaError">Enter a valid Google account email.</p>
              ) : null}
              {status === "sent" ? (
                <p className="betaStatus betaSuccess">
                  Thanks! If your email app did not open, send your Google account email to{" "}
                  <a className="betaLink" href={`mailto:${betaEmailAddress}`}>
                    {betaEmailAddress}
                  </a>
                  .
                </p>
              ) : null}

              <div className="betaActions">
                <button className={`btn btnPrimary ${canSubmit ? "" : "btnDisabled"}`} type="submit" disabled={!canSubmit}>
                  Request Android beta
                </button>
              </div>

              <p className="betaHint">
                Already approved?{" "}
                <a className="betaLink" href={googlePlayUrl} target="_blank" rel="noreferrer">
                  Open the Play Store link
                </a>
                .
              </p>
            </form>
          </div>
        </div>
      ) : null}
    </>
  );
}
