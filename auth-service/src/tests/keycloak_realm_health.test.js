'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH       = ':memory:';
process.env.KC_ISSUER     = 'http://keycloak-test/realms/kabutare-hospital';
process.env.KC_REALM      = 'kabutare-hospital';
process.env.KC_ADMIN_URL  = 'http://keycloak-test';
process.env.KC_CLIENT_ID  = 'auth-service-test';
process.env.KC_CLIENT_SECRET = 'test-secret';

// ── Mock Keycloak Admin API ────────────────────────────────────────────────────
const mockKcAdminFetch = jest.fn();
jest.mock('../utils/keycloakAdmin', () => ({
  kcAdminFetch: (...args) => mockKcAdminFetch(...args),
}));

const kcOk = (data, status = 200) => Promise.resolve({
  ok: status < 300,
  status,
  headers: { get: () => null },
  json: () => Promise.resolve(data),
  text: () => Promise.resolve(JSON.stringify(data)),
});

const { checkAndFixVerifyEmailFlag } = require('../utils/keycloakRealmHealth');

beforeEach(() => {
  mockKcAdminFetch.mockReset();
});

describe('checkAndFixVerifyEmailFlag', () => {
  test('1. Dérive détectée et corrigée', async () => {
    mockKcAdminFetch
      .mockImplementationOnce(() => kcOk({ realm: 'kabutare-hospital', verifyEmail: true, loginWithEmailAllowed: true }))
      .mockImplementationOnce(() => kcOk({}));

    await checkAndFixVerifyEmailFlag();

    expect(mockKcAdminFetch).toHaveBeenCalledTimes(2);
    expect(mockKcAdminFetch.mock.calls[1][1].method).toBe('PUT');
    expect(JSON.parse(mockKcAdminFetch.mock.calls[1][1].body)).toEqual({
      realm: 'kabutare-hospital',
      verifyEmail: false,
      loginWithEmailAllowed: true,
    });
  });

  test('2. Pas de dérive (no-op)', async () => {
    mockKcAdminFetch.mockImplementationOnce(() => kcOk({ verifyEmail: false }));

    await checkAndFixVerifyEmailFlag();

    expect(mockKcAdminFetch).toHaveBeenCalledTimes(1);
  });

  test('3. verifyEmail absent (no-op)', async () => {
    mockKcAdminFetch.mockImplementationOnce(() => kcOk({ realm: 'kabutare-hospital' }));

    await checkAndFixVerifyEmailFlag();

    expect(mockKcAdminFetch).toHaveBeenCalledTimes(1);
  });

  test('4. GET échoue (503)', async () => {
    mockKcAdminFetch.mockResolvedValue(kcOk({}, 503));

    await expect(checkAndFixVerifyEmailFlag()).resolves.toBeUndefined();
    expect(mockKcAdminFetch).toHaveBeenCalledTimes(1);
  });

  test('5. PUT échoue (500)', async () => {
    const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    mockKcAdminFetch
      .mockImplementationOnce(() => kcOk({ verifyEmail: true }))
      .mockImplementationOnce(() => kcOk({}, 500));

    await expect(checkAndFixVerifyEmailFlag()).resolves.toBeUndefined();

    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining('Échec de la correction automatique'));
    errorSpy.mockRestore();
  });

  test('6. Échec réseau pur (bonus)', async () => {
    mockKcAdminFetch.mockRejectedValue(new Error('ECONNREFUSED'));

    await expect(checkAndFixVerifyEmailFlag()).resolves.toBeUndefined();
  });
});
