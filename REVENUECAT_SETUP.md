# RevenueCat (DOODL Pro) setup

## 1) App Store Connect products

Create:
- **Auto-renewable subscription** (Monthly): `$3.99` (set the tier for USD), pick your localization, add it to a subscription group.
- **Non-consumable** (Lifetime): `$29.99`.

Pick product identifiers you like (example):
- `doodl_pro_monthly`
- `doodl_pro_lifetime`

## 2) RevenueCat dashboard

1. Create a project → add your iOS app (bundle id must match Xcode).
2. Add the two products.
3. Create an **Entitlement** named `pro`.
4. Create an **Offering** (e.g. “default”) and attach:
   - a **Monthly** package
   - a **Lifetime** package
5. Make sure the entitlement `pro` is granted by both products.

## 3) Add the SDK to Xcode (SPM)

In Xcode:
- File → Add Package Dependencies…
- URL: `https://github.com/RevenueCat/purchases-ios-spm`
- Add the `RevenueCat` product to the `DOODL.` target.
- (Optional, for RevenueCat template paywalls) Add the `RevenueCatUI` product to the `DOODL.` target.

## 3b) RevenueCat template paywall (optional)

If you want to use a RevenueCat **Paywall Template**:
- In RevenueCat Dashboard → **Paywalls** → create a paywall from a template.
- Attach it to your **current Offering** (the same Offering that contains your Monthly + Lifetime packages).
- In-app, `DOODL./ProPaywallView.swift` will automatically use the template when `RevenueCatUI` is linked.

## 4) Add your RevenueCat API key

Set `RevenueCatApiKey` in `DOODL--Info.plist` (your **Public SDK Key** from RevenueCat).

## 5) Where it’s wired in the app

- App boot config: `DOODL./DOODL_App.swift`
- Manager: `DOODL./PurchaseManager.swift`
- Paywall UI: `DOODL./ProPaywallView.swift`
- Settings entrypoint: `DOODL./DashboardView.swift`
- Example Pro gating (extra colors): `DOODL./DoodleCanvasView.swift`
