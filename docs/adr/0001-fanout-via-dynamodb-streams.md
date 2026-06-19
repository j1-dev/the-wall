# Fan-out via DynamoDB Streams rather than synchronous Lambda

The write Lambda only persists the incoming Message to DynamoDB. A separate Lambda, triggered by DynamoDB Streams, reads the new item and fans out to all connected Visitors via the API Gateway Management API. This decouples the write path from the delivery path: a slow or failing fan-out cannot block or fail the write, and the two concerns can be scaled, monitored, and retried independently.

## Considered Options

**Synchronous fan-out in the same Lambda** — simpler and lower latency, but couples write durability to delivery. If the fan-out is slow (many connections) the write Lambda times out; if it errors partway through, some Visitors get the message and others don't with no retry mechanism.
