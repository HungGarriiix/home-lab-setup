// Homepage renders service groups without ids; give each one an id from its name
// (e.g. "Welcome" -> #welcome) so custom.css can target groups by name instead of position.
// Groups render client-side and can re-render, so re-apply on DOM changes.
(() => {
  const slug = (text) =>
    text.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

  const tagGroups = () => {
    document.querySelectorAll(".services-group").forEach((group) => {
      if (group.id) return;
      // Groups with `header: false` have no name heading and are left untouched
      const name = group.querySelector(":scope .service-group-name");
      if (!name) return;
      const id = slug(name.textContent);
      // Never steal an id Homepage already uses (e.g. a group named "Services" vs #services)
      if (id && !document.getElementById(id)) group.id = id;
    });
  };

  tagGroups();
  new MutationObserver(tagGroups).observe(document.body, { childList: true, subtree: true });
})();
