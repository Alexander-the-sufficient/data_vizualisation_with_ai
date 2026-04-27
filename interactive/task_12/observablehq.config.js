// Observable Framework config for Task 12 — global earthquakes 1980–2025.
// Deployed to: https://alexander-the-sufficient.github.io/data_vizualisation_with_ai/task_12/
//
// `base` is critical: GitHub Pages serves this project under a subpath
// (/data_vizualisation_with_ai/task_12/), and Framework needs to know the
// subpath so all CSS/JS asset URLs in the built output resolve correctly.
// Setting it from day one keeps dev-server URLs aligned with production.

export default {
  title: "Where the Earth's plates grind",
  root: "src",
  output: "dist",
  base: "/data_vizualisation_with_ai/task_12/",
  pager: false,
  toc: false,
  search: false,
  cleanUrls: true,
  head: '<meta name="viewport" content="width=device-width,initial-scale=1">'
};
