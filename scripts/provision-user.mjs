#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { stdin, stdout } from 'node:process';

function option(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index < 0 ? undefined : process.argv[index + 1];
}

function required(name) {
  const value = option(name)?.trim();
  if (!value) throw new Error(`Missing required option --${name}`);
  return value;
}

function prompt(question) {
  return new Promise((resolve) => {
    stdout.write(question);
    stdin.setEncoding('utf8');
    stdin.once('data', (value) => resolve(value.trim()));
  });
}

function firestoreValue(value) {
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  throw new TypeError('Unsupported Firestore value');
}

async function main() {
  const projectId = required('project');
  const uid = required('uid');
  const displayName = required('name');
  const email = required('email').toLowerCase();
  const role = required('role');
  const confirmation = required('confirm-project');

  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) {
    throw new Error('Invalid Firebase project ID format.');
  }
  if (confirmation !== projectId) {
    throw new Error('Project confirmation did not match. No data was written.');
  }
  if (uid.length < 1 || uid.length > 128 || uid.includes('/') || /[\\u0000-\\u001f]/.test(uid)) {
    throw new Error('UID format is invalid. Copy the exact UID from Firebase Authentication.');
  }
  if (!displayName || displayName.length > 120) {
    throw new Error('Display name must contain 1–120 characters.');
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('A valid email address is required.');
  }
  if (!['admin', 'it_manager'].includes(role)) {
    throw new Error('Role must be admin or it_manager.');
  }

  const typed = await prompt(`Type CREATE PROFILE to provision ${uid} in ${projectId}: `);
  if (typed !== 'CREATE PROFILE') {
    stdout.write('Cancelled. No data was written.\n');
    return;
  }

  let accessToken;
  try {
    accessToken = execFileSync(
      'gcloud',
      ['auth', 'application-default', 'print-access-token'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
    ).trim();
  } catch {
    throw new Error('Google Cloud ADC not available. Run gcloud auth application-default login.');
  }
  if (!accessToken) throw new Error('Google Cloud ADC returned an empty access token.');

  const fields = {
    displayName: firestoreValue(displayName),
    email: firestoreValue(email),
    role: firestoreValue(role),
    isActive: firestoreValue(true),
    createdAt: { timestampValue: new Date().toISOString() },
  };
  const endpoint = new URL(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${encodeURIComponent(uid)}`,
  );
  endpoint.searchParams.set('currentDocument.exists', 'false');

  const response = await fetch(endpoint, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });

  if (response.status === 409 || response.status === 412) {
    throw new Error('A user profile already exists for this UID. Nothing was overwritten.');
  }
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Firestore rejected provisioning (${response.status}): ${detail}`);
  }

  stdout.write(`Created active ${role} profile for ${email} (UID: ${uid}) in ${projectId}.\n`);
  stdout.write('Authentication account/password were not created or changed.\n');
}

main().catch((error) => {
  console.error(`Provisioning failed: ${error.message}`);
  process.exitCode = 1;
});
