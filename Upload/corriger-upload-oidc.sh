#!/bin/bash
set -e

echo "Mise a jour de la version de @vercel/blob dans package.json..."

if grep -q '"@vercel/blob": "0.23.4"' package.json; then
  sed -i 's/"@vercel\/blob": "0.23.4"/"@vercel\/blob": "2.8.1"/' package.json
  echo "package.json mis a jour (0.23.4 -> 2.8.1)."
else
  echo "ATTENTION : la ligne exacte \"@vercel/blob\": \"0.23.4\" n'a pas ete trouvee dans package.json."
  echo "Verifie manuellement la ligne @vercel/blob dans package.json et remplace la valeur par 2.8.1."
fi

echo ""
echo "Installation des dependances (cela va mettre a jour package-lock.json)..."
npm install

echo ""
echo "Termine. Prochaine etape : git add, commit, pull, push (voir les instructions)."
