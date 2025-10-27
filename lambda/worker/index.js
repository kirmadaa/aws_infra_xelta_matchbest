exports.handler = async (event) => { console.log("worker", event); return { statusCode: 200 }; };
