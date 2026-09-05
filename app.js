// ClauDeck landing page: tiny, dependency-free.
(function () {
  const KEYS = "assets/keys/";

  // Reveal on scroll
  const io = new IntersectionObserver(
    (entries) => entries.forEach((e) => e.isIntersecting && e.target.classList.add("in")),
    { threshold: 0.12 },
  );
  document.querySelectorAll(".reveal").forEach((el) => io.observe(el));
  // Safety net: never leave content hidden (print, reader mode, odd scroll containers).
  setTimeout(() => document.querySelectorAll(".reveal").forEach((el) => el.classList.add("in")), 2500);

  // Hero deck: cycle key images to suggest a live deck.
  document.querySelectorAll("#hero-deck img[data-cycle]").forEach((img) => {
    const frames = img.dataset.cycle.split(",");
    let i = 0;
    const period = img.hasAttribute("data-fast") ? 600 : 2600 + Math.random() * 1400;
    setInterval(() => {
      i = (i + 1) % frames.length;
      img.src = KEYS + frames[i] + ".png";
    }, period);
  });

  // Usage layout tabs
  const tabs = document.getElementById("usage-tabs");
  const usageKey = document.getElementById("usage-key");
  if (tabs && usageKey) {
    tabs.addEventListener("click", (ev) => {
      const b = ev.target.closest("button");
      if (!b) return;
      tabs.querySelectorAll("button").forEach((x) => x.classList.toggle("on", x === b));
      usageKey.src = KEYS + b.dataset.key + ".png";
    });
  }

  const STORE = {
    lite: "https://marketplace.elgato.com/product/claudeck-lite-c9984dee-ad07-40c3-a319-0062a4a7d788",
    pro: "https://marketplace.elgato.com/product/claudeck-2ed8dd1e-1a28-4442-b5df-7d2e16d4f6d1",
  };
  document.querySelectorAll("[data-store]").forEach((a) => {
    a.href = STORE[a.dataset.store] || "#pricing";
    a.target = "_blank";
    a.rel = "noopener";
  });
})();
