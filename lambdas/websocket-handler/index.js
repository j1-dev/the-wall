import { uuid } from 'uuid';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';

const ddb = new DynamoDBClient({ region: 'us-east-1' });

export const handler = async (event) => {
	console.log('Received event:', JSON.stringify(event, null, 2));
	const routeKey = event.requestContext.routeKey;

	switch (routeKey) {
		case '$connect':
			return handleConnect(event);
		case '$disconnect':
			return handleDisconnect(event);
		case '$default':
			return handleDefault(event);
		default:
			return {
				statusCode: 400,
				body: 'Invalid route key',
			};
	}
}

const handleConnect = async (event) => {
	const connectionId = event.requestContext.connectionId;
	const doc = DynamoDBDocumentClient.from(ddb);
	const pk = `CONNECTION#${connectionId}`;
	const sk = `CONNECTION#${connectionId}`;
	const type = "CONNECTION"
	
	const item = {
		PK: pk,
		SK: sk,
		Type: type,
		ConnectionId: connectionId,
		CreatedAt: new Date().toISOString(),
	};

	try {
		await doc.send(
			new PutCommand({
				TableName: process.env.TABLE_NAME,
				Item: item,
			})
		);
		console.log(`Connection ${connectionId} added to DynamoDB`);
		return {
			statusCode: 200,
			body: 'Connected',
		};
	} catch (error) {
		console.error('Error adding connection to DynamoDB:', error);
		return {
			statusCode: 500,
			body: 'Failed to connect',
		};
	}
}

const handleDisconnect = async (event) => {
	const connectionId = event.requestContext.connectionId;
	const doc = DynamoDBDocumentClient.from(ddb);
	const pk = `CONNECTION#${connectionId}`;
	const sk = `CONNECTION#${connectionId}`;

	try {
		await doc.send(
			new DeleteCommand({
				TableName: process.env.TABLE_NAME,
				Key: { PK: pk, SK: sk },
			})
		);
		console.log(`Connection ${connectionId} removed from DynamoDB`);
		return {
			statusCode: 200,
			body: 'Disconnected',
		};
	} catch (error) {
		console.error('Error removing connection from DynamoDB:', error);
		return {
			statusCode: 500,
			body: 'Failed to disconnect',
		};
	}
}

const handleDefault = async (event) => {
	const connectionId = event.requestContext.connectionId;
	const pk = "MESSAGE"
	const sk =  `${new Date().toISOString()}#${connectionId}`;
	
}