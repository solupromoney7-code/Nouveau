// Connecteur entre les pages (navigateur) et les routes API du même site.
// Les pages et l'API tournent dans la même application Next.js, donc on
// appelle simplement /api/... sans avoir besoin d'URL absolue.

const TOKEN_KEY = "plume_token";

export function saveToken(token) {
  if (typeof window !== "undefined") window.localStorage.setItem(TOKEN_KEY, token);
}

export function getToken() {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(TOKEN_KEY);
}

export function clearToken() {
  if (typeof window !== "undefined") window.localStorage.removeItem(TOKEN_KEY);
}

// Appel API générique. Ajoute automatiquement le token d'authentification
// s'il existe, et remonte une erreur lisible plutôt qu'un objet brut.
export async function api(path, { method = "GET", body, auth = true } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (auth) {
    const token = getToken();
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  const res = await fetch(path, {
    method,
    headers,
    ...(body && { body: JSON.stringify(body) }),
  });

  let data = null;
  try {
    data = await res.json();
  } catch {
    // Certaines réponses (204, HTML) n'ont pas de JSON — ce n'est pas une erreur en soi.
  }

  if (!res.ok) {
    const message = data?.error || `Erreur ${res.status}`;
    const error = new Error(message);
    error.status = res.status;
    error.data = data;
    throw error;
  }

  return data;
}
