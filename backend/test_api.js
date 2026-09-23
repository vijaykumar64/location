const http = require('http');
const io = require('socket.io-client');

const PORT = 5000;
const BASE_URL = `http://127.0.0.1:${PORT}`;

function post(path, data) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(data);
    const req = http.request(
      `${BASE_URL}${path}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      },
      (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, data: JSON.parse(body) });
          } catch (_) {
            resolve({ status: res.statusCode, text: body });
          }
        });
      }
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function get(path) {
  return new Promise((resolve, reject) => {
    http.get(`${BASE_URL}${path}`, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(body) });
        } catch (_) {
          resolve({ status: res.statusCode, text: body });
        }
      });
    }).on('error', reject);
  });
}

async function runTests() {
  console.log('--- Starting Backend Verification Tests ---');

  // 1. Health check
  console.log('1. Testing GET /api/health...');
  const health = await get('/api/health');
  console.log('Health check response:', health);
  if (health.status !== 200) throw new Error('Health check failed');

  // 2. Validation tests
  console.log('\n2. Testing input validations on POST /api/location...');
  const invalidLat = await post('/api/location', { latitude: 120, longitude: 78.48, accuracy: 5 });
  if (invalidLat.status !== 400) throw new Error('Latitude out-of-bounds validation failed');

  const invalidLng = await post('/api/location', { latitude: 17.38, longitude: 200, accuracy: 5 });
  if (invalidLng.status !== 400) throw new Error('Longitude out-of-bounds validation failed');

  const invalidAcc = await post('/api/location', { latitude: 17.38, longitude: 78.48, accuracy: -2 });
  if (invalidAcc.status !== 400) throw new Error('Negative accuracy validation failed');

  const missingCoords = await post('/api/location', { accuracy: 10 });
  if (missingCoords.status !== 400) throw new Error('Missing coordinates validation failed');

  const nullLat = await post('/api/location', { latitude: null, longitude: 78.48, accuracy: 5 });
  if (nullLat.status !== 400) throw new Error('Null latitude validation failed');

  const stringCoords = await post('/api/location', { latitude: "17.38", longitude: 78.48, accuracy: 5 });
  if (stringCoords.status !== 400) throw new Error('String coordinates validation failed');

  console.log('All validation checks passed with 400 Bad Request!');

  // 3. Socket.IO listener test
  console.log('\n3. Testing Socket.IO connection & locationUpdated event...');
  const socket = io(BASE_URL, { transports: ['websocket'] });

  const socketEventPromise = new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('Socket.IO event timeout')), 5000);
    socket.on('locationUpdated', (data) => {
      clearTimeout(timeout);
      resolve(data);
    });
  });

  await new Promise((resolve) => socket.on('connect', resolve));
  console.log('Socket.IO client connected successfully!');

  // 4. Update location for X
  console.log('\n4. Testing POST /api/location with valid coordinates for X...');
  const validLocation = {
    latitude: 17.385044,
    longitude: 78.486671,
    accuracy: 8.5
  };
  const updateRes = await post('/api/location', validLocation);
  console.log('POST /api/location response:', updateRes.status, updateRes.data);
  if (updateRes.status !== 200) throw new Error('Failed to update location');
  if (updateRes.data._id !== 'X') throw new Error('Location document _id must be "X"');

  // 5. Verify Socket.IO received event
  console.log('\n5. Verifying Socket.IO received "locationUpdated" event...');
  const socketData = await socketEventPromise;
  console.log('Socket.IO event data received by Viewer Y:', socketData);
  if (socketData.latitude !== validLocation.latitude || socketData.longitude !== validLocation.longitude) {
    throw new Error('Socket.IO coordinates mismatch');
  }

  // 6. Test GET /api/location for Y
  console.log('\n6. Testing GET /api/location for Viewer Y...');
  const getRes = await get('/api/location');
  console.log('GET /api/location response:', getRes.status, getRes.data);
  if (getRes.status !== 200) throw new Error('Failed to retrieve location');
  if (getRes.data._id !== 'X') throw new Error('Retrieved document must have _id "X"');

  socket.disconnect();
  console.log('\nAll backend tests PASSED successfully! 🎉');
  process.exit(0);
}

runTests().catch((err) => {
  console.error('\nTest failed:', err);
  process.exit(1);
});
