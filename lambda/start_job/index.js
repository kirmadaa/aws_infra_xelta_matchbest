const { DynamoDBClient, PutItemCommand } = require("@aws-sdk/client-dynamodb");
const { SQSClient, SendMessageCommand } = require("@aws-sdk/client-sqs");
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require("@aws-sdk/client-apigatewaymanagementapi");

const ddb = new DynamoDBClient({});
const sqs = new SQSClient({});

exports.handler = async (event) => {
  console.log("StartJob event:", JSON.stringify(event, null, 2));

  const connectionId = event.requestContext.connectionId;
  const body = JSON.parse(event.body || "{}");
  const action = body.action || "";
  const match = /^\/models\/([^/]+)\/generate$/.exec(action);
  if (!match) {
    console.log("Ignoring non-generate action:", action);
    return { statusCode: 200, body: JSON.stringify({ message: "ignored" }) };
  }

  const modelId = match[1];
  const jobId = `job-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

  // Write job record
  await ddb.send(new PutItemCommand({
    TableName: process.env.JOBS_TABLE,
    Item: {
      jobId: { S: jobId },
      connectionId: { S: connectionId },
      modelId: { S: modelId },
      status: { S: "queued" },
      createdAt: { N: `${Date.now()}` }
    }
  }));

  // Queue the job
  await sqs.send(new SendMessageCommand({
    QueueUrl: process.env.JOB_QUEUE_URL,
    MessageBody: JSON.stringify({ jobId, modelId, payload:body.payload })
  }));

  // 🔥 Actively ACK back to the same WebSocket connection
  const endpoint = `https://${process.env.API_ID}.execute-api.${process.env.AWS_REGION}.amazonaws.com/${process.env.STAGE}`;
  const apiGw = new ApiGatewayManagementApiClient({ endpoint });
  const ack = { jobId, modelId, status: "accepted" };

  try {
    await apiGw.send(
      new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: Buffer.from(JSON.stringify(ack), "utf8"),
      })
    );
    console.log("Ack sent:", ack);
  } catch (err) {
    console.error("Failed to send ack:", err);
  }

  // Still return a 200 (optional)
  return { statusCode: 200, body: JSON.stringify(ack) };
};
