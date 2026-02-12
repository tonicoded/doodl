"use client";

import { useState, type CSSProperties, type FormEvent } from "react";
import { submitAndroidBetaEmail } from "../app/h/supabase";

type Props = {
  appStoreUrl: string;
  googlePlayUrl: string;
  betaEmail: string;
  source?: string;
  rowStyle?: CSSProperties;
};

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function StoreBadges({ appStoreUrl, googlePlayUrl, betaEmail, source, rowStyle }: Props) {
  const [isOpen, setIsOpen] = useState(false);
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "sending" | "error" | "sent">("idle");
  const [errorMessage, setErrorMessage] = useState("");
  const [showContactLink, setShowContactLink] = useState(false);
  const trimmedEmail = email.trim();
  const canSubmit = trimmedEmail.length > 0 && status !== "sending";
  const betaEmailAddress = betaEmail || "anthonyvvza@gmail.com";

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!EMAIL_PATTERN.test(trimmedEmail)) {
      setStatus("error");
      setErrorMessage("Enter a valid Google account email.");
      setShowContactLink(false);
      return;
    }
    setStatus("sending");
    setErrorMessage("");
    setShowContactLink(false);
    try {
      await submitAndroidBetaEmail(trimmedEmail, source);
      setEmail(trimmedEmail);
      setStatus("sent");
    } catch {
      setStatus("error");
      setErrorMessage("Something went wrong.");
      setShowContactLink(true);
    }
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
            setErrorMessage("");
            setShowContactLink(false);
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
                  if (errorMessage) {
                    setErrorMessage("");
                  }
                  if (showContactLink) {
                    setShowContactLink(false);
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
                <p className="betaStatus betaError">
                  {errorMessage}
                  {showContactLink ? (
                    <>
                      {" "}
                      Contact{" "}
                      <a className="betaLink" href={`mailto:${betaEmailAddress}`}>
                        {betaEmailAddress}
                      </a>
                      .
                    </>
                  ) : null}
                </p>
              ) : null}
              {status === "sent" ? (
                <p className="betaStatus betaSuccess">Thanks! You are on the Android beta list.</p>
              ) : null}
              {status === "sending" ? (
                <p className="betaStatus betaPending">Sending...</p>
              ) : null}

              <div className="betaActions">
                <button className={`btn btnPrimary ${canSubmit ? "" : "btnDisabled"}`} type="submit" disabled={!canSubmit}>
                  {status === "sending" ? "Sending..." : "Request Android beta"}
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
