import { GoogleLogin } from "@react-oauth/google";
import { jwtDecode } from "jwt-decode";
import { useState } from "react";

export default function LoginGate({ onLoggedIn }) {
  const [error, setError] = useState(null);

  const handleSuccess = (credentialResponse) => {
    try {
      if (!credentialResponse.credential) {
        throw new Error("No recibimos credenciales de Google.");
      }
      const profile = jwtDecode(credentialResponse.credential);
      onLoggedIn({
        name: profile.name,
        email: profile.email,
        avatar: profile.picture
      });
      setError(null);
    } catch (err) {
      setError(err.message || "No pudimos validar tus credenciales.");
    }
  };

  const handleError = () => {
    setError("No pudimos iniciar sesión con Google. Intenta nuevamente.");
  };

  return (
    <div className="login-panel">
      <h2>Bienvenido al buscador</h2>
      <p>Ingresa con Google para comenzar a descubrir departamentos.</p>
      <GoogleLogin onSuccess={handleSuccess} onError={handleError} />
      {error ? <p className="error">{error}</p> : null}
    </div>
  );
}
