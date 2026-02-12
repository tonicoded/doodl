# DOODL. website (Next.js)

This folder contains a small responsive website (landing page + Privacy Policy + Terms of Service) for DOODL.

## Run locally

```bash
cd legal
npm install
npm run dev
```

## Build static

This project uses `output: "export"` in `next.config.js`, so you can deploy it as a static site.

```bash
cd legal
npm install
npm run build
```

The static output will be in `legal/out/`.

## Deploy

- **Vercel**: import the repo, set the project root to `legal/`, deploy.
- **Netlify / Cloudflare Pages**: build command `npm run build`, publish directory `out`.
