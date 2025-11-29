export default function ListingCard({ listing }) {
  const cardStyle = listing.image_url
    ? { "--listing-photo": `url(${listing.image_url})` }
    : undefined;

  return (
    <article
      className={`listing-card${listing.image_url ? " has-image" : ""}`}
      style={cardStyle}
    >
      <div className="listing-content">
        <header>
          <p className="listing-source">{listing.source}</p>
          <h3>{listing.title}</h3>
          <p className="listing-address">{listing.address || listing.comuna}</p>
        </header>
        <section className="listing-body">
          <dl>
            <div>
              <dt>Precio</dt>
              <dd>
                {listing.currency?.toUpperCase() === "CLP"
                  ? Intl.NumberFormat("es-CL", {
                      style: "currency",
                      currency: "CLP",
                      maximumFractionDigits: 0
                    }).format(listing.price_clp || 0)
                  : `${listing.currency} ${listing.price_clp}`}
              </dd>
            </div>
            <div>
              <dt>Comuna</dt>
              <dd>{listing.comuna || "Sin información"}</dd>
            </div>
            <div>
              <dt>Dormitorios</dt>
              <dd>{listing.bedrooms ?? "?"}</dd>
            </div>
            <div>
              <dt>Área</dt>
              <dd>{listing.area_m2 ? `${listing.area_m2} m²` : "?"}</dd>
            </div>
          </dl>
        </section>
        <footer>
          <a
            href={listing.url}
            target="_blank"
            rel="noreferrer"
            className="listing-link"
          >
            Ver publicación original
          </a>
        </footer>
      </div>
    </article>
  );
}
