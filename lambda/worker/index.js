// worker/index.js (AWS SDK v3) - updated to return region-hosted presigned GET URL
const https = require('https');
const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require('@aws-sdk/client-apigatewaymanagementapi');

const region = process.env.AWS_REGION || 'ap-south-1';
const s3 = new S3Client({ region });
const ddbClient = new DynamoDBClient({ region });
const ddb = DynamoDBDocumentClient.from(ddbClient);

const MAX_DIRECT_BYTES = 120 * 1024; // 120 KB
const JOBS_TABLE = process.env.JOBS_TABLE;
const HOST_NAME = process.env.BACKEND_API_ENDPOINT;
const PORT = process.env.PORT;
const OUTPUT_BUCKET = process.env.OUTPUT_BUCKET;
const API_ID = process.env.API_ID;
const STAGE = process.env.STAGE;

// function httpPostToShopdew(modelId, payload = {}, headers = {}) {
//   return new Promise((resolve, reject) => {
//     const data = JSON.stringify(payload || {});
//     console.log("Post Headers: ", headers);
//     const options = {
//       hostname: 'xelta-dev-ap-south-1-nlb-de7845dc16cfd5c9.elb.ap-south-1.amazonaws.com',
//       port:8080,
//       path: `/api/models/${encodeURIComponent(modelId)}/generate`,
//       method: 'POST',
//       headers: {
//         ...headers,
//         'Content-Type': 'application/json',
//         'Content-Length': Buffer.byteLength(data)
//       },
//       timeout: 840000
//     };

//     console.log("options: ", options);
//     const req = https.request(options, (res) => {
//       const chunks = [];
//       let total = 0;
//       const contentType = res.headers['content-type'] || '';
//       res.on('data', (c) => { chunks.push(c); total += c.length; });
//       res.on('end', () => {
//         const buffer = Buffer.concat(chunks, total);
//         resolve({ statusCode: res.statusCode, headers: res.headers, buffer, contentType });
//       });
//     });

//     req.on('timeout', () => { req.destroy(new Error('Request timeout')); });
//     req.on('error', (err) => reject(err));
//     req.write(data);
//     req.end();
//   });
// }

function httpPostToShopdew(modelId, payload = {}, headers = {}) {
  const http = require('http');

  return new Promise((resolve, reject) => {
    const data = JSON.stringify(payload || {});
    console.log("Post Headers:", headers);

    const options = {
      hostname: HOST_NAME, // your NLB DNS
      port: PORT, // 👈 change to 5000 if your ECS listens on 5000
      path: `/api/models/${encodeURIComponent(modelId)}/generate`,
      method: 'POST',
      headers: {
        ...headers,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      },
      timeout: 840000
    };

    console.log("HTTP options:", options);

    const req = http.request(options, (res) => {
      const chunks = [];
      let total = 0;
      const contentType = res.headers['content-type'] || '';

      res.on('data', (chunk) => {
        chunks.push(chunk);
        total += chunk.length;
      });

      res.on('end', () => {
        const buffer = Buffer.concat(chunks, total);
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          buffer,
          contentType
        });
      });
    });

    req.on('timeout', () => {
      req.destroy(new Error('Request timeout'));
    });

    req.on('error', (err) => {
      console.error('HTTP request failed:', err);
      reject(err);
    });

    req.write(data);
    req.end();
  });
}

async function uploadToS3(jobId, buffer, contentType) {
  const ext = contentType.includes('json') ? '.json' :
              contentType.includes('image/') ? `.${contentType.split('/')[1].split(';')[0]}` :
              contentType.includes('video/') ? `.${contentType.split('/')[1].split(';')[0]}` :
              '.bin';
  const key = `results/${jobId}${ext}`;

  // Upload object
  await s3.send(new PutObjectCommand({
    Bucket: OUTPUT_BUCKET,
    Key: key,
    Body: buffer,
    ContentType: contentType
  }));

  // Generate a region-hosted presigned GET URL (expires in 1 hour)
  const getCmd = new GetObjectCommand({ Bucket: OUTPUT_BUCKET, Key: key });
  const url = await getSignedUrl(s3, getCmd, { expiresIn: 3600 }); // seconds

  return { key, url };
}

async function postToConnection(connectionId, payloadBuffer) {
  const endpoint = `https://${API_ID}.execute-api.${region}.amazonaws.com/${STAGE}`;
  const apigw = new ApiGatewayManagementApiClient({ region, endpoint });
  await apigw.send(new PostToConnectionCommand({
    ConnectionId: connectionId,
    Data: payloadBuffer
  }));
}

exports.handler = async (event) => {
  for (const rec of event.Records) {
    let msg;
    try { msg = JSON.parse(rec.body); } catch (e) { console.error('Invalid SQS message', e); continue; }
    const jobId = msg.jobId;
    const modelId = msg.modelId;
    if (!jobId || !modelId) { console.warn('missing jobId/modelId', msg); continue; }

    // fetch job record
    let jobRec;
    try {
      const r = await ddb.send(new GetCommand({ TableName: JOBS_TABLE, Key: { jobId } }));
      jobRec = r.Item || {};
    } catch (e) {
      console.error('ddb.get failed', e); throw e;
    }

    const connectionId = jobRec.connectionId;
    const payload = msg.payload || jobRec.payload || {};

    try {
      console.log("Forward Headers:", payload?._auth);
      const forwardHeaders = (payload && payload._auth) ? payload._auth : {};
      const res = await httpPostToShopdew(modelId, payload, forwardHeaders);

      const buffer = res.buffer;
      const contentType = res.contentType || 'application/octet-stream';

      if (buffer.length <= MAX_DIRECT_BYTES) {
        if (contentType.includes('application/json') || contentType.startsWith('text/')) {
          let wrapper;
          try {
            const parsed = JSON.parse(buffer.toString('utf8'));
            wrapper = JSON.stringify({ jobId, modelId, status: 'done', result: parsed });
          } catch (e) {
            wrapper = JSON.stringify({ jobId, modelId, status: 'done', resultText: buffer.toString('utf8') });
          }
          if (connectionId) await postToConnection(connectionId, Buffer.from(wrapper, 'utf8'));
        } else {
          const base64 = buffer.toString('base64');
          const wrapper = JSON.stringify({ jobId, modelId, status: 'done', contentType, base64 });
          if (Buffer.byteLength(wrapper, 'utf8') <= MAX_DIRECT_BYTES) {
            if (connectionId) await postToConnection(connectionId, Buffer.from(wrapper, 'utf8'));
          } else {
            const { url } = await uploadToS3(jobId, buffer, contentType);
            await ddb.send(new UpdateCommand({
              TableName: JOBS_TABLE,
              Key: { jobId },
              UpdateExpression: 'SET #s=:s, resultUrl=:r, finishedAt=:f',
              ExpressionAttributeNames: { '#s': 'status' },
              ExpressionAttributeValues: { ':s': 'done', ':r': url, ':f': Date.now() }
            }));
            if (connectionId) {
              const notif = JSON.stringify({ jobId, modelId, status: 'done', resultUrl: url, note: 'result too large for WebSocket' });
              await postToConnection(connectionId, Buffer.from(notif, 'utf8'));
            }
            continue;
          }
        }

        await ddb.send(new UpdateCommand({
          TableName: JOBS_TABLE,
          Key: { jobId },
          UpdateExpression: 'SET #s=:s, finishedAt=:f',
          ExpressionAttributeNames: { '#s': 'status' },
          ExpressionAttributeValues: { ':s': 'done', ':f': Date.now() }
        }));
      } else {
        const { url } = await uploadToS3(jobId, buffer, contentType);
        await ddb.send(new UpdateCommand({
          TableName: JOBS_TABLE,
          Key: { jobId },
          UpdateExpression: 'SET #s=:s, resultUrl=:r, finishedAt=:f',
          ExpressionAttributeNames: { '#s': 'status' },
          ExpressionAttributeValues: { ':s': 'done', ':r': url, ':f': Date.now() }
        }));
        if (connectionId) {
          const notif = JSON.stringify({ jobId, modelId, status: 'done', resultUrl: url, note: 'result too large for WebSocket' });
          await postToConnection(connectionId, Buffer.from(notif, 'utf8'));
        }
      }

    } catch (err) {
      console.error('Worker processing error for job', jobId, err);
      try {
        await ddb.send(new UpdateCommand({
          TableName: JOBS_TABLE,
          Key: { jobId },
          UpdateExpression: 'SET #s=:s, error=:e, finishedAt=:f',
          ExpressionAttributeNames: { '#s': 'status' },
          ExpressionAttributeValues: { ':s': 'failed', ':e': String(err.message || err), ':f': Date.now() }
        }));
      } catch(e2) { console.error('failed to update job status', e2); }
      throw err;
    }
  }
};
