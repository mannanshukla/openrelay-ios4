// Serves the static site and signs owner-only uploads to the project's bucket.
// Downloads (the IPAs) live in the public bucket and are linked directly from the pages.
const express = require('express');
const path = require('path');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const app = express();
const PORT = process.env.PORT || 8080;
const token = process.env.ADMIN_TOKEN;
const s3ok = ['S3_ENDPOINT', 'S3_REGION', 'S3_BUCKET', 'S3_ACCESS_KEY_ID', 'S3_SECRET_ACCESS_KEY'].every(k => process.env[k]);
const s3 = s3ok ? new S3Client({ endpoint: process.env.S3_ENDPOINT, region: process.env.S3_REGION, forcePathStyle: true,
  credentials: { accessKeyId: process.env.S3_ACCESS_KEY_ID, secretAccessKey: process.env.S3_SECRET_ACCESS_KEY } }) : null;
if (!s3ok) console.log('S3_* variables not set; the sign route is disabled until add_storage runs');
if (!token) console.log('ADMIN_TOKEN not set; the sign route is disabled');

// owner only: returns a presigned PUT for one object key
app.get('/admin/sign', async (req, res) => {
  if (!token || req.query.token !== token) return res.status(401).json({ error: 'no' });
  if (!s3) return res.status(503).json({ error: 'storage not configured' });
  const key = String(req.query.key || ''); if (!/^[A-Za-z0-9_.\/-]+$/.test(key) || key.includes('..')) return res.status(400).json({ error: 'bad key' });
  const url = await getSignedUrl(s3, new PutObjectCommand({ Bucket: process.env.S3_BUCKET, Key: key, ContentType: String(req.query.type || 'application/octet-stream') }), { expiresIn: 600 });
  res.json({ url, public: (process.env.S3_PUBLIC_URL || '') + '/' + key });
});

app.use(express.static(path.join(__dirname), { extensions: ['html'], index: 'index.html', maxAge: '1h' }));
app.listen(PORT, '0.0.0.0', () => console.log('site on ' + PORT));
