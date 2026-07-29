# The Wall — Task List

## Task 1 — Project scaffold
**Status:** [x] done

## Task 2 — DynamoDB table design
**Status:** [x] done

## Task 3 — WebSocket handler: $connect
**Status:** [x] done

## Task 4 — WebSocket handler: $disconnect
**Status:** [x] done

## Task 5 — WebSocket handler: $default (post a message)
**Status:** [x] done

## Task 6 — Fan-out Lambda
**Status:** [x] done

## Task 7 — Terraform: DynamoDB + WebSocket API Gateway + websocket-handler Lambda
**Status:** [x] done

## Task 8 — Terraform: fan-out Lambda + DynamoDB Streams trigger
**Status:** [x] done

---

## Task 9 — Fix createdAt field inconsistency

**Goal:** Messages stored in DynamoDB use the canonical `createdAt` field name instead of `timestamp`.

**Why it matters:** The fan-out Lambda reads `newImage.createdAt` to push to connected Visitors. If the write handler stores it as `timestamp`, connected Visitors receive `undefined` for that field. Data written to storage must match what readers expect.

**Steps:**
1. In `lambdas/websocket-handler/index.ts`, find the item object built before the `PutCommand` and rename the `timestamp` field to `createdAt`.
2. Verify the value assigned to it is still `new Date().toISOString()`.
3. Rebuild the Lambda.

**Done when:** The stored item has `createdAt` and the fan-out Lambda's `newImage.createdAt` reference would resolve correctly.

**Status:** [x] done

---

## Task 10 — Push message history on $connect

**Goal:** When a Visitor connects, the server immediately pushes the 50 most recent Messages to that Visitor over their WebSocket connection.

**Why it matters:** A Visitor who opens the board after messages have been posted would otherwise see a blank board until a new message arrives. Sending history on connect gives them immediate context.

**Steps:**
1. In `lambdas/websocket-handler/index.ts`, update `handleConnect` to query DynamoDB for the 50 most recent Messages after saving the Connection.
2. Use a `QueryCommand` on the main table with `PK = "MESSAGE"`, sorted descending by SK, limited to 50 items.
3. Reverse the result so messages are in chronological order (oldest first).
4. Use `ApiGatewayManagementApiClient` to push the history array to the connecting Visitor's `connectionId`.
5. Update the IAM policy in `terraform/main.tf` to grant the websocket-handler Lambda `dynamodb:Query` on the table.
6. Rebuild and redeploy via Terraform.

**Done when:** A new WebSocket connection immediately receives a JSON payload containing an array of up to 50 messages, each with `text`, `author`, and `createdAt` fields, in chronological order.

**Status:** [x] done

---

## Task 11 — Frontend project layout

**Goal:** The frontend has its own home in the repo, and `index.html`'s script reference and the README's project structure both point at the same location.

**Why it matters:** `index.html` currently sits at repo root and expects `app.js` next to it, but there's an empty `frontend/` directory nobody uses yet. Before writing any behavior, the project structure needs to be unambiguous.

**Steps:**
1. Move `index.html` from the repo root into `frontend/`.
2. Confirm the `<script src="app.js">` tag in `index.html` still resolves relative to its new location (it should, since `app.js` will live in the same folder).
3. Create an empty `app.js` file inside `frontend/` (just the file, no code yet — that's Task 12 onward).
4. Update the "Project structure" section in `README.md` so it lists `frontend/` (containing `index.html` and `app.js`) instead of `index.html` at root.
5. Update the "Status" section in `README.md` if needed to reflect that frontend work is now in progress.

**Done when:** `frontend/index.html` and `frontend/app.js` both exist, the root no longer has `index.html`, and `README.md`'s project structure section matches reality.

**Status:** [x] done

---

## Task 12 — Build the HTML skeleton

**Goal:** `frontend/index.html` has four identifiable pieces that later tasks will wire up: a place to display the current Author name, a container to hold rendered Messages, a form to submit a new Message, and an element to show the connection status.

**Why it matters:** You chose to write your own markup from scratch rather than recover the original. Every later task needs a DOM element to attach behavior to — deciding these elements now, and naming them consistently, means Tasks 13-18 can refer to "the status element" or "the messages container" without you having to reverse-engineer your own markup later.

**Steps:**
1. Add an element that will show the connecting/connected/disconnected status (Task 13 will wire this up).
2. Add an element that will display the current Author name (Task 15 will wire this up).
3. Add a container element that will hold the rendered list of Messages (Tasks 16 and 17 will populate this).
4. Add a form containing a text input or textarea for a new Message's text, and a submit button (Task 18 will wire this up).
5. Give each of these four elements an `id` you'll remember — write them down (e.g. as a short comment at the top of `app.js`) since every later task will refer back to them by name.
6. Styling is optional at this point — none of the later tasks' Done-when criteria depend on how it looks, only on the elements existing and being selectable (e.g. via `getElementById`).

**Done when:** `frontend/index.html`, opened in a browser, shows (even unstyled) a status area, an author name area, an empty message list area, and a message submission form — and you know the `id` of each.

**Status:** [x] done

---

## Task 13 — Open the WebSocket connection with a status indicator

**Goal:** Opening `frontend/index.html` in a browser opens a live WebSocket connection to the deployed API Gateway endpoint, and the page visibly shows whether it's connected.

**Why it matters:** This is the foundation everything else builds on — history, live messages, and sending all depend on having an open Connection (per CONTEXT.md's definition) first.

**Steps:**
1. Get the current `websocket_url` from `terraform output` in the `terraform/` directory.
2. In `app.js`, declare a constant holding that URL as a string (you'll re-run this step and update the constant whenever LocalStack restarts and the URL changes — note this in a comment).
3. Open a `new WebSocket(...)` connection using that constant when the page loads.
4. Using the status element's `id` from Task 12, wire up the WebSocket's `open` and `close` events to update its text (e.g. "connected" / "disconnected").
5. Open the page in a browser and confirm the status element shows "connected" once the socket opens (check the browser Network/WS inspector tab to confirm the handshake succeeded).
6. Temporarily stop LocalStack (or block the connection) and confirm the status flips to "disconnected".

**Done when:** Opening `frontend/index.html` in a browser shows "connected" in the status area within a second or two, confirmed via the browser's WebSocket inspector.

**Status:** [ ] not started

---

## Task 14 — Auto-reconnect on disconnect

**Goal:** If the WebSocket connection drops for any reason, `app.js` automatically attempts to reopen it without the Visitor needing to refresh the page.

**Why it matters:** LocalStack restarts, network blips, and idle timeouts are normal — CONTEXT.md defines a Connection as something that's deleted on `$disconnect`, but from the Visitor's perspective the Board should feel persistently live, not something that silently goes stale.

**Steps:**
1. Wrap the WebSocket-creation logic from Task 13 in a function you can call more than once (e.g. `connect()`).
2. In the WebSocket's `close` event handler, after updating the status indicator, schedule a call back to that `connect()` function after a short delay.
3. Decide on a retry delay (a fixed delay like 2-3 seconds is enough for now — don't over-engineer exponential backoff yet).
4. Guard against piling up multiple simultaneous reconnect attempts (make sure a `close` event doesn't schedule a second retry if one is already pending).
5. Test it: open the page, confirm "connected", then stop LocalStack's docker-compose service and watch the status flip to "disconnected" and then keep attempting to reconnect (check the browser console/network tab for repeated connection attempts).
6. Restart LocalStack and confirm the page automatically shows "connected" again without a manual page refresh.

**Done when:** Killing and restarting the LocalStack container causes the page to show "disconnected" and then automatically recover to "connected" on its own.

**Status:** [ ] not started

---

## Task 15 — Author identity: generate and persist an Author name

**Goal:** Each Visitor gets an Author name in the Adjective+Animal+Number form (per CONTEXT.md) on first visit, and it's reused on every subsequent visit from the same browser.

**Why it matters:** The Author is how a Visitor is identified — CONTEXT.md is explicit that there's no login, so this generated name is the only identity a Message will carry.

**Steps:**
1. Decide on (or write) two small word lists: adjectives and animals.
2. Write a function that picks one random adjective, one random animal, and a random number, and joins them into a string like `SilentFox42`.
3. On page load, check `localStorage` for an existing Author name.
4. If none exists, generate one with your function and save it to `localStorage`.
5. If one exists, reuse it instead of generating a new one.
6. Using the author-name element's `id` from Task 12, display the current Author name in it.
7. Test it: load the page, note the Author name, refresh the page, and confirm the same name appears (not a new random one).
8. Clear `localStorage` (via browser devtools) and refresh — confirm a new Author name is generated.

**Done when:** Refreshing the page keeps the same Author name; clearing `localStorage` and refreshing produces a new one.

**Status:** [ ] not started

---

## Task 16 — Render message history on connect

**Goal:** When `app.js` receives a history payload (an array of Messages) over the socket, it replaces whatever is currently rendered with that array, in order.

**Why it matters:** Per your Task 10 backend work, every `$connect` (including ones triggered by the auto-reconnect from Task 14) sends the 50 most recent Messages. Since `app.js` now reconnects automatically, it needs a clear, consistent rule for what to do each time that history arrives — replace-the-whole-list rather than merging, to keep the logic simple and always consistent with the server's view.

**Steps:**
1. In the WebSocket's `message` event handler, parse the incoming JSON payload.
2. Add a check: if the parsed payload is an array, treat it as a history batch (single objects — new fan-out messages — are Task 17).
3. Write a function that clears the messages container from Task 12 and re-renders it from scratch given an array of Messages.
4. For each Message in the array, render its `author`, `text`, and `createdAt` — decide on a simple layout (e.g. one child element per Message with those three pieces of text somewhere inside it).
5. Call this render function whenever a history array arrives — including after an auto-reconnect, not just the first connection.
6. Post a couple of messages (via Task 18's form, once it exists) and confirm they appear in chronological order (oldest first) after a page refresh.

**Done when:** Loading the page shows existing Messages from the Board immediately, oldest first, and reconnecting (Task 14) re-renders the same list without duplicates.

**Status:** [ ] not started

---

## Task 17 — Render live incoming messages from fan-out

**Goal:** A single new Message posted by any Visitor appears in the rendered list within a second, without a page refresh.

**Why it matters:** This is the fan-out path (per CONTEXT.md) — the whole reason the system uses WebSockets and DynamoDB Streams instead of polling. It's the payload shape your Task 16 code explicitly needs to distinguish from a history batch.

**Steps:**
1. In the same `message` event handler from Task 16, add the other branch of the payload-shape check: if the parsed payload is a single object (not an array), treat it as one new Message from fan-out.
2. Reuse the per-Message rendering logic from Task 16 to append this one Message to the bottom of the messages container, rather than clearing everything.
3. If the container can grow tall, consider giving it a fixed height and `overflow-y: auto` so it scrolls instead of pushing the rest of the page down — optional polish, not required for Done-when.
4. Test with two browser tabs open side by side: post a message in one tab (once Task 18's form exists) and confirm it appears in the other tab's list without a refresh.

**Done when:** Two tabs open on the page both show a newly posted Message appear within about a second of it being sent from either tab.

**Status:** [ ] not started

---

## Task 18 — Message submission form with client-side validation

**Goal:** The form from Task 12 sends a well-formed message over the socket, and rejects (client-side) anything the server would reject anyway.

**Why it matters:** The `$default` route has no route response configured in Terraform, so a server-side 400 for an invalid message is invisible to the Visitor — it only shows up in Lambda logs. Client-side validation is the only feedback the Visitor will actually get, so it needs to mirror the server's rules (`lambdas/websocket-handler/index.ts`: text non-empty and <=500 chars, author non-empty and <=100 chars).

**Steps:**
1. Add a `submit` event listener to the form from Task 12 that prevents the default page reload.
2. Read the value from the text input/textarea and the current Author name (from Task 15).
3. Add a `maxlength` attribute (or equivalent check) on the text input matching the server's 500-character limit.
4. Before sending, check that the trimmed text isn't empty and isn't over 500 characters — mirror the exact conditions from `handleDefault` in `lambdas/websocket-handler/index.ts`.
5. If validation fails, prevent sending and give the Visitor some visible feedback (e.g. disable the submit button, or show a message) rather than silently dropping it.
6. If validation passes, send a JSON payload over the socket shaped like `{"action": "message", "text": "...", "author": "..."}`.
7. Clear the input after a successful send.
8. Test: try submitting an empty message and a 501+ character message, and confirm neither is sent (check the Network/WS inspector to be sure nothing goes out).

**Done when:** Submitting the form with valid text sends it over the socket and it shows up (per Task 17) in both open tabs; submitting empty or over-length text is blocked client-side before anything is sent.

**Status:** [ ] not started

---

## Task 19 — End-to-end verification across two tabs

**Goal:** Confirm the whole system — storage, fan-out, history, reconnect, and the frontend — works together as a single, global, real-time Board.

**Why it matters:** This is the acceptance criterion for the entire project.

**Steps:**
1. Open two separate browser tabs (or a normal + incognito window, so they get different Author names) pointed at `frontend/index.html`.
2. Confirm both show the same message history on load.
3. Post a message from tab A; confirm it appears in tab B within about a second.
4. Post a message from tab B; confirm it appears in tab A.
5. Restart the LocalStack container while both tabs are open; confirm both tabs show "disconnected" then recover to "connected" automatically.
6. After reconnecting, confirm no messages are duplicated in either tab's list.

**Done when:** Both tabs stay in sync in real time, survive a LocalStack restart without manual refresh, and never show duplicate messages.

**Status:** [ ] not started
