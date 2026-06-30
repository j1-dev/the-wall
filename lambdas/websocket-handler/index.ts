import { v4 } from "uuid";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  PutCommand,
  DeleteCommand,
} from "@aws-sdk/lib-dynamodb";
import { APIGatewayEvent } from "aws-lambda";

const ddb = new DynamoDBClient({
  region: "us-east-1",
  ...(process.env.DYNAMODB_ENDPOINT && {
    endpoint: process.env.DYNAMODB_ENDPOINT,
  }),
});

export const handler = async (event: APIGatewayEvent) => {
  console.log("Received event:", JSON.stringify(event, null, 2));
  const routeKey = event.requestContext.routeKey;

  switch (routeKey) {
    case "$connect":
      return handleConnect(event);
    case "$disconnect":
      return handleDisconnect(event);
    case "$default":
      return handleDefault(event);
    default:
      return {
        statusCode: 400,
        body: "Invalid route key",
      };
  }
};

const handleConnect = async (event: APIGatewayEvent) => {
  const connectionId = event.requestContext.connectionId;
  const doc = DynamoDBDocumentClient.from(ddb);
  const pk = `CONNECTION#${connectionId}`;
  const sk = `CONNECTION#${connectionId}`;
  const type = "CONNECTION";

  const item = {
    PK: pk,
    SK: sk,
    type: type,
    connectionId: connectionId,
    createdAt: new Date().toISOString(),
  };

  try {
    await doc.send(
      new PutCommand({
        TableName: process.env.TABLE_NAME,
        Item: item,
      }),
    );
    console.log(`Connection ${connectionId} added to DynamoDB`);
    return {
      statusCode: 200,
      body: "Connected",
    };
  } catch (error) {
    console.error("Error adding connection to DynamoDB:", error);
    return {
      statusCode: 500,
      body: "Failed to connect",
    };
  }
};

const handleDisconnect = async (event: APIGatewayEvent) => {
  const connectionId = event.requestContext.connectionId;
  const doc = DynamoDBDocumentClient.from(ddb);
  const pk = `CONNECTION#${connectionId}`;
  const sk = `CONNECTION#${connectionId}`;

  try {
    await doc.send(
      new DeleteCommand({
        TableName: process.env.TABLE_NAME,
        Key: { PK: pk, SK: sk },
      }),
    );
    console.log(`Connection ${connectionId} removed from DynamoDB`);
    return {
      statusCode: 200,
      body: "Disconnected",
    };
  } catch (error) {
    console.error("Error removing connection from DynamoDB:", error);
    return {
      statusCode: 500,
      body: "Failed to disconnect",
    };
  }
};

const handleDefault = async (event: APIGatewayEvent) => {
  const { text, author } = JSON.parse(event.body ?? "{}");
  const connectionId = event.requestContext.connectionId;
  const createdAt = new Date().toISOString();
  const pk = "MESSAGE";
  const sk = `${createdAt}#${v4()}`; // Unique SK for each message

  const validText = text && text.trim() !== "" && text.length <= 500;
  const validAuthor = author && author.trim() !== "" && author.length <= 100;
  if (!validText || !validAuthor) {
    return {
      statusCode: 400,
      body: "Invalid message text",
    };
  }

  const doc = DynamoDBDocumentClient.from(ddb);
  const item = {
    PK: pk,
    SK: sk,
    type: "MESSAGE",
    text: text,
    author: author,
    createdAt: createdAt,
  };

  try {
    await doc.send(
      new PutCommand({
        TableName: process.env.TABLE_NAME,
        Item: item,
      }),
    );
    console.log(`Message from ${connectionId} added to DynamoDB`);
    return {
      statusCode: 200,
      body: "Message received",
    };
  } catch (error) {
    console.error("Error adding message to DynamoDB:", error);
    return {
      statusCode: 500,
      body: "Failed to process message",
    };
  }
};

