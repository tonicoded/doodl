import Link from "next/link";

export const metadata = {
  title: "Privacy Policy"
};

export default function PrivacyPage() {
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

        <h1>Privacy Policy</h1>
        <p className="sheetMeta">Last updated: December 17, 2025</p>

        <p>
          DOODL. is built for sharing doodles with friends and family in small groups. This policy explains what we collect,
          why, and how you stay in control. If you do not agree, please do not use DOODL.
        </p>

        <h2>1. What we collect</h2>
        <p>We collect only what we need to run DOODL:</p>
        <ul>
          <li>
            <strong>Account details:</strong> username, a pairing/recovery code, a profile ID, and optional avatar URL.
          </li>
          <li><strong>Group info:</strong> groups you create or join and group membership.</li>
          <li><strong>Doodles:</strong> doodles you create and send (including image/base64 content).</li>
          <li>
            <strong>Activity data:</strong> timestamps and “last active” signals to show online/offline status and streaks.
          </li>
          <li>
            <strong>Push tokens:</strong> APNs device tokens and environment (sandbox/production) to deliver notifications.
          </li>
          <li><strong>Device/app info:</strong> app version, device/OS version, and limited logs for support and reliability.</li>
          <li>
            <strong>Purchase data (if you buy Pro):</strong> subscription status and entitlement information. Payments are handled by
            Apple. We may use a third-party provider (RevenueCat) to manage subscription status across devices.
          </li>
        </ul>

        <h2>2. How we store it</h2>
        <p>
          DOODL. uses managed cloud services (including Supabase) to store and sync your data. Data is encrypted in transit.
          Access is restricted by least privilege. Media (like avatars) may be stored in managed object storage.
        </p>

        <h2>3. How we use data</h2>
        <ul>
          <li>Operate the app (sync doodles, groups, inbox/unread counts).</li>
          <li>Send notifications when new doodles arrive.</li>
          <li>Provide support when you contact us.</li>
          <li>Maintain safety and prevent abuse.</li>
          <li>Improve reliability and plan features using aggregated, privacy-focused insights.</li>
        </ul>

        <h2>4. Sharing</h2>
        <p>
          We do not sell your personal data. We share limited information with service providers (e.g., Supabase and Apple Push
          Notification service) under agreements that require privacy and security. We may share data if required by law.
        </p>
        <p>
          If you purchase Pro, we may share information with <strong>RevenueCat</strong> (subscription management) and Apple’s App
          Store services to validate and manage purchases.
        </p>

        <h2>5. Retention and control</h2>
        <ul>
          <li>You can request deletion of your account and data; deleting your account removes your content from active systems.</li>
          <li>We may keep minimal records if required for legal or security purposes.</li>
          <li>You can request a copy or correction of your data by contacting us.</li>
        </ul>

        <h2>6. Security</h2>
        <p>
          We use encryption in transit, access controls, and monitoring to protect your data. No system is perfect, so we
          encourage strong device security and keeping your app updated.
        </p>

        <h2>7. Children</h2>
        <p>
          DOODL. is not directed to children under 13, and we do not knowingly collect data from them. If you believe a child has
          provided data, contact us to remove it.
        </p>

        <h2>8. International use</h2>
        <p>
          Your data may be processed and stored in countries other than where you live. We apply protections described here
          regardless of location.
        </p>

        <h2>9. Changes</h2>
        <p>
          We may update this policy. We will notify you through the app when changes are significant. Continuing to use DOODL.
          means you accept the updated policy.
        </p>

        <h2>10. Contact</h2>
        <p>
          Questions or requests? Email <a href="mailto:anthonyvvza@gmail.com">anthonyvvza@gmail.com</a>.
        </p>
      </article>
    </main>
  );
}
