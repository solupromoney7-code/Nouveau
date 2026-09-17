import Head from "next/head";
import "../styles/globals.css";

export default function App({ Component, pageProps }) {
  return (
    <>
      <Head>
        <title>Plume — Vendez votre livre sans savoir vendre</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="description" content="Plateforme de vente pour auteurs indépendants. L'IA génère votre page de vente à partir de votre livre." />
      </Head>
      <Component {...pageProps} />
    </>
  );
}
