#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { stdin, stdout } from 'node:process';
import { validateProvisioningInput } from './provision-user-validation.mjs';

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

  const validated = validateProvisioningInput({
    projectId, confirmation, uid, displayName, email, role,
  });

  const safeProjectId = validated.projectId;
  const safeUid = validated.uid;
  const safeDisplayName = validated.displayName;
  const safeEmail = validated.email;
  const safeRole = validated.role;

  const typed = await prompt(`Type CREATE PROFILE to provision ${safeUid} in ${safeProjectId}: `);
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
    displayName: firestoreValue(safeDisplayName),
    email: firestoreValue(safeEmail),
    role: firestoreValue(safeRole),
    isActive: firestoreValue(true),
    createdAt: { timestampValue: new Date().toISOString() },
  };
  const endpoint = new URL(
    `https://firestore.googleapis.com/v1/projects/${safeProjectId}/databases/(default)/documents/users/${encodeURIComponent(safeUid)}`,
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

  stdout.write(`Created active ${safeRole} profile for ${safeEmail} (UID: ${safeUid}) in ${safeProjectId}.\n`);
  stdout.write('Authentication account/password were not created or changed.\n');
}

main().catch((error) => {
  console.error(`Provisioning failed: ${error.message}`);
  process.exitCode = 1;
});
