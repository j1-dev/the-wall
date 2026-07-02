# Architecture

```mermaid
flowchart TB
    subgraph Client["Browser (Visitor)"]
        UI["index.html + app.js<br/>localStorage: Author name"]
    end

    subgraph AWS["AWS (LocalStack via docker-compose)"]
        APIGW["API Gateway WebSocket API<br/>routes: $connect / $disconnect / $default"]

        subgraph WriteLambda["websocket-handler Lambda"]
            Connect["handleConnect<br/>store CONNECTION item<br/>send last 50 messages"]
            Disconnect["handleDisconnect<br/>delete CONNECTION item"]
            Default["handleDefault<br/>validate + store MESSAGE item"]
        end

        DDB[("DynamoDB table: the-wall<br/>PK/SK single-table<br/>GSI: type-index<br/>Streams: NEW_IMAGE")]

        Stream["DynamoDB Stream<br/>(INSERT events)"]

        subgraph FanoutLambda["fanout Lambda"]
            Fanout["query CONNECTION items via type-index<br/>PostToConnection for each<br/>delete on 410 Gone"]
        end
    end

    UI -- "WebSocket connect" --> APIGW
    APIGW -- "$connect" --> Connect
    APIGW -- "$disconnect" --> Disconnect
    APIGW -- "$default: {text, author}" --> Default

    Connect -- "PutItem CONNECTION" --> DDB
    Connect -- "Query MESSAGE (history)" --> DDB
    Connect -. "PostToConnection (history)" .-> UI
    Disconnect -- "DeleteItem CONNECTION" --> DDB
    Default -- "PutItem MESSAGE" --> DDB

    DDB --> Stream
    Stream -- "triggers" --> Fanout
    Fanout -- "Query type=CONNECTION" --> DDB
    Fanout -. "PostToConnection (new message)" .-> UI
    Fanout -- "DeleteItem (stale, 410)" --> DDB
```

## Notes

- **Board**: single global DynamoDB table (`the-wall`), single-table design distinguishing `CONNECTION` and `MESSAGE` items via `PK`/`type`.
- **Fan-out decoupling** ([ADR 0001](adr/0001-fanout-via-dynamodb-streams.md)): the write path (`websocket-handler`) only persists Messages; delivery to all Connections happens asynchronously in a separate `fanout` Lambda triggered by DynamoDB Streams, so slow/failing delivery can't block or fail writes.
- **Infra as code** ([ADR 0002](adr/0002-terraform-for-infrastructure.md)): Terraform provisions API Gateway, Lambdas, IAM roles, and DynamoDB against LocalStack (`docker-compose.yml`), chosen over SAM/CDK for tooling consistency.
- Stale connections (410 Gone from `PostToConnectionCommand`) are cleaned up lazily by the `fanout` Lambda rather than proactively on disconnect failure.
