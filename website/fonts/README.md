# Iconenlettertype

`material-symbols.woff2` is een subset van Material Symbols Outlined (gevuld,
400, 24 px) met de 21 iconen die de pagina's gebruiken. Het lettertype is van
Google (Apache License 2.0) en wordt hier zelf geserveerd, zodat een bezoeker
van de website geen verzoek naar Google stuurt.

Een icoon toevoegen: voeg de naam toe aan de pagina (`<span class="ms">naam</span>`),
haal de css op met alle namen alfabetisch gesorteerd en met een Chrome-user-agent:

    curl -A "Mozilla/5.0 ... Chrome/120.0.0.0 Safari/537.36" \
      "https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,1,0&icon_names=a,b,c&display=block"

download het `woff2`-bestand uit die css en vervang `material-symbols.woff2`;
verhoog daarna de `?v=` achter `style.css` in alle pagina's.
