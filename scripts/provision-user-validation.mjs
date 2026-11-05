export function validateProvisioningInput({ projectId, confirmation, uid, displayName, email, role }) {
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId ?? '')) {
    throw new Error('Invalid Firebase project ID format.');
  }
  if (confirmation !== projectId) {
    throw new Error('Project confirmation did not match. No data was written.');
  }
  if (typeof uid !== 'string' || uid.length < 1 || uid.length > 128 ||
      uid.includes('/') || /[\u0000-\u001f]/.test(uid)) {
    throw new Error('UID format is invalid. Copy the exact UID from Firebase Authentication.');
  }
  if (typeof displayName !== 'string' || !displayName.trim() || displayName.length > 120) {
    throw new Error('Display name must contain 1–120 characters.');
  }
  if (typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('A valid email address is required.');
  }
  if (!['admin', 'it_manager'].includes(role)) {
    throw new Error('Role must be admin or it_manager.');
  }
  return { projectId, uid, displayName: displayName.trim(), email: email.toLowerCase(), role };
}
