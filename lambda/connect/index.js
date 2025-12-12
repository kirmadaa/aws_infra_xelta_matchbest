// connect/index.js (AWS SDK v3)
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'ap-south-1' });
const ddb = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
  const connectionId = event.requestContext && event.requestContext.connectionId;
  if (!connectionId) return { statusCode: 400, body: 'no connectionId' };
  try {
    await ddb.send(new PutCommand({
      TableName: process.env.CONNECTIONS_TABLE,
      Item: { connectionId, connectedAt: Date.now() }
    }));
    return { statusCode: 200, body: 'connected' };
  } catch (err) {
    console.error('connect error', err);
    return { statusCode: 500, body: 'connect failed' };
  }
};
