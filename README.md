# The Wall

A single, global, real-time message board where anyone can post and read messages anonymously under a randomly generated name (e.g. `SilentFox42`). No accounts, no login — just an open board and a WebSocket connection.

See [CONTEXT.md](./CONTEXT.md) for the domain language (Board, Message, Author, Visitor, Connection, Fan-out) and [docs/architecture.md](./docs/architecture.md) for the full system diagram.

## How it works

- A Visitor's browser opens a WebSocket connection to an API Gateway WebSocket API.
- The `websocket-handler` Lambda handles `$connect` (register the connection, send the last 50 messages), `$disconnect` (remove the connection), and `$default` (validate and store a new message).
- Everything lives in one DynamoDB table (`the-wall`), single-table design with a `type-index` GSI to look up active connections.
- Writing a message only persists it — delivery is decoupled. A DynamoDB Stream on the table triggers a separate `fanout` Lambda, which queries all active connections and pushes the new message to each one, cleaning up any connection that returns a `410 Gone`. See [ADR 0001](./docs/adr/0001-fanout-via-dynamodb-streams.md) for why.
- Infrastructure is provisioned with Terraform against LocalStack rather than real AWS. See [ADR 0002](./docs/adr/0002-terraform-for-infrastructure.md) for why Terraform over SAM/CDK.

## Project structure

```
index.html                     static frontend entry point
lambdas/
  websocket-handler/           $connect / $disconnect / $default handler
  fanout/                      DynamoDB Streams -> fan-out to connections
terraform/                     infra: DynamoDB, API Gateway WebSocket, Lambdas, IAM
docker-compose.yml             LocalStack (ministack image)
docs/
  architecture.md              architecture diagram (Mermaid)
  adr/                          architecture decision records
  TASKS.md                      task list / project status
```

## Prerequisites

- Docker
- Node.js 22+
- Terraform ~> 1.x
- A LocalStack auth token (for the `ministackorg/ministack` image)

## Setup

1. Copy the env file and fill in your LocalStack auth token:
   ```
   cp .env.example .env
   ```
2. Start LocalStack:
   ```
   docker-compose up -d
   ```
3. Install dependencies and provision the infrastructure:
   ```
   cd terraform
   terraform init
   terraform apply
   ```
   This builds both Lambdas (`npm run build` in each `lambdas/*` directory), zips them, and creates the DynamoDB table, WebSocket API Gateway, and Lambda functions in LocalStack.
4. Note the `websocket_url` from the `terraform apply` output — this is the WebSocket endpoint the frontend connects to.

## Status

Backend (connect/disconnect/post/fan-out/history-on-connect) and infra are done — see [docs/TASKS.md](./docs/TASKS.md). The frontend WebSocket wiring (`app.js`, referenced by `index.html` but not yet committed) is the remaining open task.
