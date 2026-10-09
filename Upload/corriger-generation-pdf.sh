#!/bin/bash
set -e

echo "Correction du bug connu de pdf-parse dans lib/ai.js..."

if grep -q 'const pdfParse = (await import("pdf-parse")).default;' lib/ai.js; then
  sed -i 's#const pdfParse = (await import("pdf-parse")).default;#const pdfParse = (await import("pdf-parse/lib/pdf-parse.js")).default;#' lib/ai.js
  echo "lib/ai.js corrige."
else
  echo "ATTENTION : la ligne attendue n'a pas ete trouvee dans lib/ai.js."
  echo "Verifie manuellement la fonction extractBookText dans lib/ai.js."
fi

echo ""
echo "Termine. Prochaine etape : git add, commit, pull, push (voir les instructions)."
