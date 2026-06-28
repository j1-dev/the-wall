import { DynamoDBStreamEvent } from "aws-lambda";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { unmarshall } from "@aws-sdk/util-dynamodb";
import {
  DeleteCommand,
  DynamoDBDocumentClient,
  QueryCommand,
} from "@aws-sdk/lib-dynamodb";
import {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand,
} from "@aws-sdk/client-apigatewaymanagementapi";

const ddb = new DynamoDBClient({
  region: "us-east-1",
  endpoint: "http://localhost:4566",
});

const apigw = new ApiGatewayManagementApiClient({
  endpoint: process.env.WEBSOCKET,
});

export const handler = async (event: DynamoDBStreamEvent) => {
  const records = event.Records;
  for (const record of records) {
    const name = record.eventName;
    if (name !== "INSERT") {
      continue;
    }

    const dynamodbRecord = record.dynamodb;
    if (!dynamodbRecord || !dynamodbRecord.NewImage) {
      console.error("No NewImage found in the DynamoDB record");
      continue;
    }

    const newImage = unmarshall(dynamodbRecord.NewImage as Record<string, any>);

    if (newImage.PK !== "MESSAGE") {
      continue;
    }

    const doc = DynamoDBDocumentClient.from(ddb);

    const result = await doc.send(
      new QueryCommand({
        TableName: process.env.TABLE_NAME,
        IndexName: "type-index",
        KeyConditionExpression: "#t = :t",
        ExpressionAttributeNames: { "#t": "type" },
        ExpressionAttributeValues: { ":t": "CONNECTION" },
      }),
    );

    const connections = (result.Items ?? []) as Record<string, any>[];

    if (connections.length === 0) {
      continue;
    }

    for (const connection of connections) {
      try {
        apigw.send(
          new PostToConnectionCommand({
            ConnectionId: connection.connectionId,
            Data: Buffer.from(
              JSON.stringify({
                text: newImage.text,
                author: newImage.author,
                createdAt: newImage.createdAt,
              }),
            ),
          }),
        );
      } catch (error: any) {
        if (error.$metadata?.httpStatusCode === 410) {
          await doc.send(
            new DeleteCommand({
              TableName: process.env.TABLE_NAME,
              Key: { PK: connection.PK, SK: connection.SK },
            }),
          );
        }
      }
    }
  }
};
