// server/utils/config.js
const mongoose = require("mongoose");

const MIN_JWT_SECRET_LENGTH = 32;
let cachedJwtSecret = null;
let cachedMongoPromise = null;

function getJwtSecret() {
  if (cachedJwtSecret) return cachedJwtSecret;

  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < MIN_JWT_SECRET_LENGTH) {
    throw new Error(
      `JWT_SECRET must be set and at least ${MIN_JWT_SECRET_LENGTH} characters long. ` +
        "Provide a strong, random secret in your environment configuration."
    );
  }

  cachedJwtSecret = secret;
  return cachedJwtSecret;
}

function getMongoUri() {
  const uri = process.env.MONGO_URI;
  if (!uri) {
    throw new Error(
      "MONGO_URI must be provided in the environment before using database helpers."
    );
  }
  return uri;
}

async function connectToDatabase() {
  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }

  if (!cachedMongoPromise) {
    mongoose.set("strictQuery", true);
    cachedMongoPromise = mongoose
      .connect(getMongoUri())
      .catch((err) => {
        cachedMongoPromise = null;
        throw err;
      });
  }

  await cachedMongoPromise;
  return mongoose.connection;
}

async function disconnectFromDatabase() {
  try {
    if (mongoose.connection.readyState !== 0) {
      await mongoose.connection.close(false);
    }
  } finally {
    cachedMongoPromise = null;
  }
}

module.exports = {
  getJwtSecret,
  MIN_JWT_SECRET_LENGTH,
  getMongoUri,
  connectToDatabase,
  disconnectFromDatabase,
};
