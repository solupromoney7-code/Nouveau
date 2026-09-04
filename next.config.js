// En-têtes de sécurité HTTP appliqués à toutes les routes. Aucun de ces
// réglages n'existait avant cet audit — Next.js ne les ajoute pas par défaut.
const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" }, // empêche le navigateur de deviner un type MIME dangereux
  { key: "X-Frame-Options", value: "DENY" }, // empêche d'intégrer le site dans une <iframe> (clickjacking)
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" }, // force HTTPS
  { key: "X-DNS-Prefetch-Control", value: "off" },
];

module.exports = {
  async headers() {
    return [
      {
        source: "/:path*",
        headers: securityHeaders,
      },
    ];
  },
};
