import { useCallback, useEffect, useState } from "react";
import { API_BASE_URL } from "../config";

const BATCH_SIZE = 5;

export default function useListings() {
  const [displayed, setDisplayed] = useState([]);
  const [pool, setPool] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [initialized, setInitialized] = useState(false);

  const fetchListings = useCallback(async () => {
    setLoading(true);
    try {
      const response = await fetch(`${API_BASE_URL}/api/listings`);
      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }
      const payload = await response.json();
      const data = payload.data || [];
      const nextBatch = data.slice(0, BATCH_SIZE);
      const remaining = data.slice(BATCH_SIZE);
      setDisplayed(nextBatch);
      setPool(remaining);
      setInitialized(true);
      setError(null);
    } catch (err) {
      setError(err.message || "No pudimos obtener los listados.");
    } finally {
      setLoading(false);
    }
  }, []);

  const loadMoreFromPool = useCallback(() => {
    setPool((currentPool) => {
      if (currentPool.length === 0) {
        fetchListings();
        return currentPool;
      }
      const nextBatch = currentPool.slice(0, BATCH_SIZE);
      setDisplayed(nextBatch);
      return currentPool.slice(BATCH_SIZE);
    });
  }, [fetchListings]);

  const consumeListing = useCallback((listingId) => {
    if (!listingId) return;
    setDisplayed((current) => current.filter((item) => item.id !== listingId));
  }, []);

  useEffect(() => {
    fetchListings();
  }, [fetchListings]);

  useEffect(() => {
    if (!initialized || loading) {
      return;
    }

    if (displayed.length === 0) {
      loadMoreFromPool();
    }
  }, [initialized, loading, displayed.length, loadMoreFromPool]);

  return {
    listings: displayed,
    loading,
    error,
    refetch: fetchListings,
    consumeListing
  };
}
