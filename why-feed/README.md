# The Why Feed

A doomscrollable feed for learning the answers to kids' "why?" questions. It's a single self-contained HTML file with no build step.

Each card is a "why ladder":

1. **Say it to a 4-year-old**: a one-line answer
2. **How it really works**: the actual mechanism, for the grown-up
3. **Try it together**: a home demo, where one exists

Each card ends with a **But why…?** button that jumps to a follow-up question.

Each card also has **Go deeper** links (Wikipedia and Simple English Wikipedia, via the `WIKI` map) and a
**Flag a problem** button.

Practice features:

- **Review**: cards you've read come back as recall cards on a spaced schedule (1, 3, 7, 16, 35, 90 days).
  You say the answer out loud, reveal it, then mark it *Nailed it* or *Fuzzy*. Due cards also appear
  in the main feed about every fifth card.
- **Guess first**: blurs the answers on every card until you've guessed out loud.

There are also **Saved** (bookmarked cards) and **Books** (a reading path with checkboxes) tabs.

Storage: reading progress, the review schedule, saved cards and ticked books live in the browser's `localStorage`
(one device). Flags go to the artifact's shared `db` collection `flags` (one doc per card:
`{cardId, q, status, notes[]}`), so Claude can read them and fix the cards. When the page runs outside
claude.ai, flags fall back to `localStorage`.

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
