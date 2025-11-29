import { useEffect, useMemo, useState } from "react";
import { GoogleOAuthProvider } from "@react-oauth/google";
import {
  Buildings,
  Heart,
  MapPinLine,
  SignOut,
  UserCircle
} from "@phosphor-icons/react";
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
            <div className="eyebrow-row">
              <Buildings size={22} weight="duotone" />
              <p className="eyebrow">Explora arriendos preseleccionados</p>
            </div>
            <p className="subtitle">
              Haz swipe para descubrir departamentos nuevos y guarda tus favoritos
              en segundos.
            </p>
          </div>
          {user ? (
            <div className="user-chip">
              {user.avatar ? (
                <img src={user.avatar} alt={user.name} />
              ) : (
                <UserCircle size={32} weight="duotone" />
              )}
              <span>{user.name}</span>
              <button onClick={handleLogout}>
                <SignOut size={18} weight="bold" />
                <span>Salir</span>
              </button>
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
              <h2>
                <Heart size={20} weight="fill" />
                <span>Me gustaron</span>
              </h2>
              {likes.length === 0 ? (
                <p>Haz swipe a la derecha para guardar.</p>
              ) : (
                <ul>
                  {likes.map((listing) => (
                    <li key={listing.id}>
                      <div className="like-title-row">
                        <Heart size={18} weight="duotone" />
                        <span className="listing-title">{listing.title}</span>
                      </div>
                      <small className="like-meta">
                        <MapPinLine size={14} weight="bold" />
                        <span>{listing.comuna}</span>
                      </small>
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
