---
title: "Where the Earth's plates grind"
toc: false
---

# Where the Earth's plates grind

Smoke-test page. Real cells land in the next iteration.

```js
const quakes = await FileAttachment("./data/quakes.csv").csv({typed: true});
```

**Row count:** ${quakes.length.toLocaleString()}

**Columns:** ${Object.keys(quakes[0]).join(", ")}

**First row:**

```js
display(quakes[0]);
```
