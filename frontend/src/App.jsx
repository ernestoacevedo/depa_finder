import { useEffect, useMemo, useState } from "react";
import { GoogleOAuthProvider } from "@react-oauth/google";
import LoginGate from "./components/LoginGate.jsx";
import SwipeDeck from "./components/SwipeDeck.jsx";
import useListings from "./hooks/useListings.js";

const googleClientId =
  import.meta.env.VITE_GOOGLE_CLIENT_ID ||
  "your-google-oauth-client-id.apps.googleusercontent.com";
const USER_STORAGE_KEY = "depa_finder:user";

export default function App() {
  const { listings, loading, error, refetch, consumeListing } = useListings();
  const [user, setUser] = useState(null);
  const [likes, setLikes] = useState([]);
  const likedIds = useMemo(() => new Set(likes.map((item) => item.id)), [likes]);

  useEffect(() => {
    try {
      const saved = localStorage.getItem(USER_STORAGE_KEY);
      if (saved) {
        setUser(JSON.parse(saved));
      }
    } catch (_) {
      // ignore storage parse errors
    }
  }, []);

  const persistUser = (nextUser) => {
    setUser(nextUser);
    try {
      if (nextUser) {
        localStorage.setItem(USER_STORAGE_KEY, JSON.stringify(nextUser));
      } else {
        localStorage.removeItem(USER_STORAGE_KEY);
      }
    } catch (_) {
      // ignore storage errors
    }
  };

  const handleSwipe = (direction, listing) => {
    if (!listing) return;

    consumeListing(listing.id);
    if (direction === "right" && !likedIds.has(listing.id)) {
      setLikes((prev) => [...prev, listing]);
    }
  };

  const handleLogout = () => persistUser(null);

  return (
    <GoogleOAuthProvider clientId={googleClientId}>
      <main className="app-shell">
        <header>
          <div className="brand-copy">
            <p className="eyebrow">Explora arriendos preseleccionados</p>
            <p className="subtitle">
              Haz swipe para descubrir departamentos nuevos y guarda tus favoritos
              en segundos.
            </p>
          </div>
          {user ? (
            <div className="user-chip">
              {user.avatar ? <img src={user.avatar} alt={user.name} /> : null}
              <span>{user.name}</span>
              <button onClick={handleLogout}>Salir</button>
            </div>
          ) : null}
        </header>
        {!user ? (
          <LoginGate onLoggedIn={persistUser} />
        ) : (
          <section className="app-content">
            <div className="deck-column">
              <SwipeDeck
                listings={listings}
                loading={loading}
                error={error}
                onSwipe={handleSwipe}
                onReload={refetch}
              />
            </div>
            <aside className="likes-panel">
              <h2>Me gustaron</h2>
              {likes.length === 0 ? (
                <p>Haz swipe a la derecha para guardar.</p>
              ) : (
                <ul>
                  {likes.map((listing) => (
                    <li key={listing.id}>
                      <span className="listing-title">{listing.title}</span>
                      <small>{listing.comuna}</small>
                    </li>
                  ))}
                </ul>
              )}
            </aside>
          </section>
        )}
      </main>
    </GoogleOAuthProvider>
  );
}
