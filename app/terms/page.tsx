import Link from "next/link";

export const metadata = {
  title: "Terms of Service"
};

export default function TermsPage() {
  return (
    <main className="doc">
      <div className="brand" style={{ marginTop: 6 }}>
        <img src="/logo.png" alt="DOODL." width={110} height={110} />
      </div>

      <article className="sheet">
        <div className="sheetHeaderRow">
          <Link className="backLink" href="/">
            ← Home
          </Link>
        </div>

        <h1>Terms of Service</h1>
        <p className="sheetMeta">Last updated: December 17, 2025</p>

        <p>
          Welcome to DOODL. By using our app, you agree to these terms. If you do not agree, please do not use DOODL.
        </p>

        <h2>1. Using DOODL.</h2>
        <p>
          You must be old enough to use your device’s app store and legally able to enter into these terms. You agree to keep your
          account secure and to use DOODL. respectfully with your friends and family.
        </p>

        <h2>2. Subscriptions &amp; purchases</h2>
        <p>
          DOODL. may offer optional in-app purchases, including auto-renewing subscriptions and a one-time “lifetime” purchase.
          Purchases are processed by Apple through the App Store.
        </p>
        <ul>
          <li>
            <strong>Free trials (if offered):</strong> if you start a trial, you will be charged at the end of the trial period
            unless you cancel before it ends.
          </li>
          <li>
            <strong>Auto-renew subscriptions:</strong> subscriptions renew automatically unless cancelled at least 24 hours before
            the end of the current period (timing and rules are controlled by Apple).
          </li>
          <li>
            <strong>Manage/cancel:</strong> you can manage or cancel in Apple ID settings on your device.
          </li>
          <li>
            <strong>Restore:</strong> use “Restore Purchases” in the app to restore eligible purchases.
          </li>
          <li>
            <strong>Refunds:</strong> refunds are handled by Apple under their policies.
          </li>
        </ul>

        <h2>3. Your content and data</h2>
        <p>
          You own the content you create (doodles, usernames, preferences). By using DOODL. you give us permission to store and
          process it so the app works for you and your groups.
        </p>

        <h2>4. Acceptable use</h2>
        <p>Do not:</p>
        <ul>
          <li>Harass, threaten, or harm others.</li>
          <li>Post illegal content or violate anyone’s privacy or rights.</li>
          <li>Attempt to disrupt, reverse engineer, or misuse DOODL.</li>
        </ul>

        <h2>5. Privacy</h2>
        <p>
          Our Privacy Policy explains what we collect and how we protect it. By using DOODL. you also agree to the Privacy Policy.
        </p>

        <h2>6. Service changes and availability</h2>
        <p>
          We may update features, limit access, or stop offering the app. We’ll aim to give notice when changes are significant.
        </p>

        <h2>7. Disclaimers</h2>
        <p>DOODL. is provided “as is” without warranties. We do not promise uninterrupted or error-free service.</p>

        <h2>8. Limitation of liability</h2>
        <p>
          To the fullest extent permitted by law, DOODL. and its team are not liable for indirect, incidental, special,
          consequential, or punitive damages, or any loss of data, revenue, profits, or goodwill arising from your use of DOODL.
        </p>

        <h2>9. Termination</h2>
        <p>You may stop using DOODL. at any time. We may suspend or end access if you violate these terms or misuse the service.</p>

        <h2>10. Changes to these terms</h2>
        <p>We may update these terms occasionally. Continued use after changes means you accept the updated terms.</p>

        <h2>11. Contact</h2>
        <p>
          Questions or concerns? Email <a href="mailto:anthonyvvza@gmail.com">anthonyvvza@gmail.com</a>.
        </p>
      </article>
    </main>
  );
}
