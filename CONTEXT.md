# Message Board

A single, global, real-time message board where anyone can post and read messages anonymously under a randomly generated name.

## Language

**Board**:
The single global space where all messages are posted and read. There is only one Board in the entire application.
_Avoid_: Channel, room, feed, chat

**Message**:
An append-only entry on the Board consisting of text (up to 500 characters), a timestamp, and an Author name. Messages are never edited or deleted.
_Avoid_: Post, entry, comment

**Author**:
The randomly generated name assigned to a visitor on their first visit, persisted in their browser. Takes the form Adjective + Animal + Number (e.g. `SilentFox42`).
_Avoid_: User, username, handle, identity

**Visitor**:
A person who opens the app in a browser. Has no account or login. Identified only by their Author name, which is stored in localStorage.
_Avoid_: User, account, member

**Connection**:
An active WebSocket session between a Visitor's browser and API Gateway. Identified by a `connectionId` assigned by API Gateway. Created on `$connect`, deleted on `$disconnect` or when a 410 Gone response is received during fan-out.
_Avoid_: Session, socket, client

**Fan-out**:
The act of pushing a newly posted Message to all active Connections. Triggered by a DynamoDB Stream event, handled by a dedicated Lambda.
_Avoid_: Broadcast, publish, notify
