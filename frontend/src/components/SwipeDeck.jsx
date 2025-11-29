import { useEffect, useMemo, useState } from "react";
import TinderCard from "react-tinder-card";
import ListingCard from "./ListingCard.jsx";

const swipeMessages = {
  left: "No es para mí",
  right: "¡Me gusta!"
};

export default function SwipeDeck({
  listings,
  onSwipe,
  loading,
  error,
  onReload
}) {
  const [lastSwipe, setLastSwipe] = useState(null);
  const stack = useMemo(() => [...listings].reverse(), [listings]);

  useEffect(() => {
    if (!lastSwipe) return;
    const timeout = setTimeout(() => setLastSwipe(null), 3000);
    return () => clearTimeout(timeout);
  }, [lastSwipe]);

  const handleSwipe = (direction, listing) => {
    setLastSwipe({
      direction,
      message: swipeMessages[direction] || "",
      listing
    });
    onSwipe?.(direction, listing);
  };

  if (loading) {
    return <p className="status">Cargando departamentos...</p>;
  }

  if (error) {
    return (
      <div className="status error">
        <p>{error}</p>
        <button onClick={onReload}>Reintentar</button>
      </div>
    );
  }

  if (!stack.length) {
    return (
      <div className="status empty">
        <p>No hay más departamentos por ahora.</p>
        <button onClick={onReload}>Actualizar listados</button>
      </div>
    );
  }

  return (
    <section className="deck">
      {stack.map((listing) => (
        <TinderCard
          className="swipe"
          key={listing.id}
          swipeRequirementType="position"
          swipeThreshold={140}
          onSwipe={(direction) => handleSwipe(direction, listing)}
          preventSwipe={["up", "down"]}
        >
          <ListingCard listing={listing} />
        </TinderCard>
      ))}
      {lastSwipe ? (
        <div className="last-swipe">
          <span>{lastSwipe.message}</span>
          <strong>{lastSwipe.listing?.title}</strong>
        </div>
      ) : null}
    </section>
  );
}
