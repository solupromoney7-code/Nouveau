import { useEffect, useState } from "react";
import { useRouter } from "next/router";
import { api, getToken, clearToken } from "./apiClient";

// Protège une page réservée aux auteurs connectés : redirige vers /connexion
// si aucun token valide, et retourne le profil une fois chargé.
export function useAuthGuard() {
  const router = useRouter();
  const [author, setAuthor] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/connexion");
      return;
    }
    api("/api/authors/me")
      .then((data) => {
        setAuthor(data);
        setLoading(false);
      })
      .catch(() => {
        clearToken();
        router.replace("/connexion");
      });
  }, [router]);

  return { author, setAuthor, loading };
}
