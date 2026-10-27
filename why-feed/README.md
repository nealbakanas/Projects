# The Why Feed

A doomscrollable feed for learning the answers to kids' "why?" questions. It's a single self-contained HTML file with no build step.

Each card is a "why ladder":

1. **Say it to a 4-year-old**: a one-line answer
2. **How it really works**: the actual mechanism, for the grown-up
3. **Try it together**: a home demo, where one exists

Each card ends with a **But why…?** button that jumps to a follow-up question.

There are also **Saved** (bookmarked cards) and **Books** (a reading path with checkboxes) tabs.
Progress is stored in the browser's `localStorage`, so it stays on one device.

## Run

Open `index.html` in a browser.

## Add cards

Append objects to the `CARDS` array in `index.html`:

```js
{ id: "unique-id", cat: "physics", q: "Question?", kid: "Toddler answer.",
  how: ["Paragraph 1", "Paragraph 2"], try: "Optional demo.", fact: "Optional fact.", next: "another-card-id" }
```

`cat` is one of `physics`, `chem`, `bio`, `body`, `earth`, `space`, `math` or `tech`.

The folder includes a `.gdignore` so the Godot project in this repo skips it.
