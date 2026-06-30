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

**Status:** [ ] not started

---

## Task 11 — Frontend: connect and display the board

**Goal:** A browser page opens a WebSocket connection, renders incoming history, and displays new messages as they arrive via fan-out.

**Why it matters:** This is the first end-to-end test of the entire system — storage, fan-out, and history retrieval all exercised together from a real browser.

**Steps:**
1. Create a minimal HTML file that opens a WebSocket connection to the API Gateway stage URL.
2. On the `message` event, handle two payload shapes: an array (history batch) and a single object (new message from fan-out).
3. Render messages as a list showing `author`, `text`, and `createdAt`.
4. Add a form to submit a new message (sends `{"action": "message", "text": "...", "author": "..."}` over the socket).
5. Generate an Author name (Adjective + Animal + Number) and persist it to `localStorage`.

**Done when:** Two browser tabs open simultaneously both show the same message board, and a message posted in one tab appears in the other within a second.

**Status:** [ ] not started
