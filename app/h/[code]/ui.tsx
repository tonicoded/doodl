"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import { submitAnonymousDoodle } from "../supabase";

type Props = {
  code: string;
};

export default function AnonymousDoodleClient({ code }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const pointerDownRef = useRef(false);
  const lastPointRef = useRef<{ x: number; y: number } | null>(null);
  const lastMidRef = useRef<{ x: number; y: number } | null>(null);

  const [strokeColor, setStrokeColor] = useState("#111111");
  const [strokeWidth, setStrokeWidth] = useState(10);
  const [isSending, setIsSending] = useState(false);
  const [statusText, setStatusText] = useState<string | null>(null);
  const [didSend, setDidSend] = useState(false);

  const appStoreUrl = (process.env.NEXT_PUBLIC_APP_STORE_URL as string | undefined) ?? "/";
  const googlePlayUrl = (process.env.NEXT_PUBLIC_GOOGLE_PLAY_URL as string | undefined) ?? "/";

  const palette = useMemo(
    () => ["#111111", "#ff2a6d", "#ff8a1f", "#ffd24a", "#6AD84A", "#2AD1D1", "#2A9CFF", "#9b5cff"],
    []
  );

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();
    const width = Math.max(1, Math.floor(rect.width * dpr));
    const height = Math.max(1, Math.floor(rect.height * dpr));

    canvas.width = width;
    canvas.height = height;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, rect.width, rect.height);
  }, []);

  function clearCanvas() {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const rect = canvas.getBoundingClientRect();
    ctx.clearRect(0, 0, rect.width, rect.height);
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, rect.width, rect.height);
  }

  function getPointFromEvent(event: React.PointerEvent<HTMLCanvasElement>) {
    const canvas = canvasRef.current;
    if (!canvas) return null;
    const rect = canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    return { x, y };
  }

  function drawLine(from: { x: number; y: number }, to: { x: number; y: number }) {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.strokeStyle = strokeColor;
    ctx.lineWidth = strokeWidth;

    ctx.beginPath();
    ctx.moveTo(from.x, from.y);
    ctx.lineTo(to.x, to.y);
    ctx.stroke();
  }

  function drawSmoothPoint(pt: { x: number; y: number }) {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.strokeStyle = strokeColor;
    ctx.lineWidth = strokeWidth;

    const last = lastPointRef.current;
    const lastMid = lastMidRef.current;
    if (!last || !lastMid) {
      lastPointRef.current = pt;
      lastMidRef.current = pt;
      ctx.beginPath();
      ctx.moveTo(pt.x, pt.y);
      ctx.lineTo(pt.x, pt.y);
      ctx.stroke();
      return;
    }

    const mid = { x: (last.x + pt.x) / 2, y: (last.y + pt.y) / 2 };
    ctx.beginPath();
    ctx.moveTo(lastMid.x, lastMid.y);
    ctx.quadraticCurveTo(last.x, last.y, mid.x, mid.y);
    ctx.stroke();

    lastPointRef.current = pt;
    lastMidRef.current = mid;
  }

  async function onSend() {
    const canvas = canvasRef.current;
    if (!canvas) return;

    setIsSending(true);
    setStatusText("sending…");
    try {
      const dataURL = canvas.toDataURL("image/png");
      await submitAnonymousDoodle(code, dataURL);
      setStatusText("sent");
      setDidSend(true);
      setTimeout(() => setStatusText(null), 1200);
      clearCanvas();
    } catch (error) {
      const message = error instanceof Error ? error.message : "failed to send";
      setStatusText(message.toLowerCase());
    } finally {
      setIsSending(false);
    }
  }

  return (
    <main className="sheet anonSheet">
      <div className="brand">
        <img src="/logo.png" alt="DOODL." width={150} height={150} />
      </div>

      <h1 className="heroTitle anonTitle">send me a doodl</h1>
      <p className="heroSub anonSub">This goes to their anonymous inbox. Your name won’t show.</p>

      <div className="anonCanvasWrap" aria-label="Canvas">
        <canvas
          ref={canvasRef}
          className="anonCanvas"
          onPointerDown={(event) => {
            pointerDownRef.current = true;
            event.currentTarget.setPointerCapture(event.pointerId);
            const pt = getPointFromEvent(event);
            if (!pt) return;
            lastPointRef.current = pt;
            lastMidRef.current = pt;
            drawSmoothPoint(pt);
          }}
          onPointerMove={(event) => {
            if (!pointerDownRef.current) return;
            const pt = getPointFromEvent(event);
            if (!pt) return;
            drawSmoothPoint(pt);
          }}
          onPointerUp={() => {
            pointerDownRef.current = false;
            lastPointRef.current = null;
            lastMidRef.current = null;
          }}
          onPointerCancel={() => {
            pointerDownRef.current = false;
            lastPointRef.current = null;
            lastMidRef.current = null;
          }}
        />
      </div>

      <div className="anonTools">
        <div className="anonPalette" aria-label="Colors">
          {palette.map((color) => {
            const selected = color.toLowerCase() === strokeColor.toLowerCase();
            return (
              <button
                key={color}
                type="button"
                className={`anonSwatch ${selected ? "anonSwatchSelected" : ""}`}
                style={{ background: color }}
                onClick={() => setStrokeColor(color)}
                aria-label={`Color ${color}`}
              />
            );
          })}
        </div>

        <div className="anonSliderRow">
          <span className="anonLabel">size</span>
          <input
            className="anonSlider"
            type="range"
            min={4}
            max={24}
            value={strokeWidth}
            onChange={(e) => setStrokeWidth(parseInt(e.target.value, 10))}
            aria-label="Brush size"
          />
          <span className="anonValue">{strokeWidth}</span>
        </div>
      </div>

      {didSend ? (
        <section className="anonSent" aria-label="Sent">
          <div className="anonSentTitleRow">
            <div className="anonSentTitle">Sent</div>
            <button
              type="button"
              className="anonSentAnother"
              onClick={() => {
                setDidSend(false);
                setStatusText(null);
              }}
            >
              send another
            </button>
          </div>
          <p className="anonSentSub">Download DOODL. to receive doodls too.</p>
          <div className="storeRow" aria-label="Download">
            <a className="storeBadge" href={appStoreUrl} target="_blank" rel="noreferrer">
              <img src="/appstore.svg" alt="Download on the App Store" />
            </a>
            <a className="storeBadge" href={googlePlayUrl} target="_blank" rel="noreferrer">
              <img src="/googleplay.svg" alt="Get it on Google Play" />
            </a>
          </div>
        </section>
      ) : null}

      <div className="anonStickyBar" aria-label="Actions">
        <button type="button" className="btn btnSecondary" onClick={clearCanvas} disabled={isSending}>
          clear
        </button>
        <button
          type="button"
          className={`btn btnPrimary ${isSending ? "btnDisabled" : ""}`}
          onClick={onSend}
          disabled={isSending}
        >
          send
        </button>
      </div>

      {statusText ? <p className="anonToast">{statusText}</p> : null}
    </main>
  );
}
