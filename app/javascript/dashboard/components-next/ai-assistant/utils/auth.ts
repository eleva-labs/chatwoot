import Auth from 'dashboard/api/auth';

export function getAuthHeaders(): Record<string, string> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (Auth.hasAuthCookie()) {
    const authData = Auth.getAuthData();
    Object.assign(headers, {
      'access-token': authData['access-token'],
      'token-type': authData['token-type'],
      client: authData.client,
      expiry: authData.expiry,
      uid: authData.uid,
    });
  }
  return headers;
}
