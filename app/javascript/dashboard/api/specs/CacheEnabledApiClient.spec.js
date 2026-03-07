import axios from 'axios';

const mockDataManager = {
  initDb: vi.fn(),
  get: vi.fn(),
  replace: vi.fn(),
  setCacheKeys: vi.fn(),
  getCacheKey: vi.fn(),
  db: true,
};

vi.mock('../../helper/CacheHelper/DataManager', () => ({
  DataManager: vi.fn(() => mockDataManager),
}));

vi.mock('axios');
global.axios = axios;

import CacheEnabledApiClient from '../CacheEnabledApiClient';

class TestApiClient extends CacheEnabledApiClient {
  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'test_model';
  }
}

describe('CacheEnabledApiClient', () => {
  let client;

  beforeEach(() => {
    delete window.location;
    window.location = { pathname: '/app/accounts/1/dashboard' };
    client = new TestApiClient('test_resource', { accountScoped: true });
    // mockReset resets implementations, so re-set db to truthy
    mockDataManager.db = true;
  });

  describe('#getFromCache', () => {
    it('falls back to network when IDB init fails', async () => {
      mockDataManager.initDb.mockRejectedValue(new Error('IDB not available'));
      axios.get.mockResolvedValue({ data: { payload: [{ id: 1 }] } });

      const result = await client.getFromCache();

      expect(result.data.payload).toEqual([{ id: 1 }]);
      expect(mockDataManager.get).not.toHaveBeenCalled();
    });

    it('falls back to network when cache_keys fetch fails', async () => {
      mockDataManager.initDb.mockResolvedValue();

      // First call: cache_keys → rejects
      // Second call: getFromNetwork → resolves
      axios.get
        .mockRejectedValueOnce(new Error('500 Internal'))
        .mockResolvedValueOnce({ data: { payload: [{ id: 2 }] } });

      const consoleSpy = vi
        .spyOn(console, 'error')
        .mockImplementation(() => {});
      const result = await client.getFromCache();

      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('cache_keys fetch failed'),
        expect.any(Error)
      );
      expect(result.data.payload).toEqual([{ id: 2 }]);
      consoleSpy.mockRestore();
    });

    it('returns cached data when cache key is valid and data exists', async () => {
      mockDataManager.initDb.mockResolvedValue();
      axios.get.mockResolvedValue({
        data: { cache_keys: { test_model: 'key-123' } },
      });
      mockDataManager.getCacheKey.mockResolvedValue('key-123');
      mockDataManager.get.mockResolvedValue([{ id: 3 }, { id: 4 }]);

      const result = await client.getFromCache();

      expect(result).toEqual({ data: { payload: [{ id: 3 }, { id: 4 }] } });
    });

    it('refetches from network when cache key is invalid', async () => {
      mockDataManager.initDb.mockResolvedValue();

      // First call: cache_keys → resolves with new-key
      // Second call: getFromNetwork (refetchAndCommit) → resolves with payload
      axios.get
        .mockResolvedValueOnce({
          data: { cache_keys: { test_model: 'new-key' } },
        })
        .mockResolvedValueOnce({ data: { payload: [{ id: 5 }] } });

      mockDataManager.getCacheKey.mockResolvedValue('old-key');
      mockDataManager.replace.mockResolvedValue();
      mockDataManager.setCacheKeys.mockResolvedValue();

      const result = await client.getFromCache();

      expect(result.data.payload).toEqual([{ id: 5 }]);
    });
  });

  describe('#refetchAndCommit', () => {
    it('awaits dataManager.replace before setCacheKeys', async () => {
      const callOrder = [];
      mockDataManager.initDb.mockResolvedValue();
      mockDataManager.replace.mockImplementation(async () => {
        callOrder.push('replace');
      });
      mockDataManager.setCacheKeys.mockImplementation(async () => {
        callOrder.push('setCacheKeys');
      });
      axios.get.mockResolvedValue({ data: { payload: [{ id: 1 }] } });

      await client.refetchAndCommit('new-key');

      expect(callOrder).toEqual(['replace', 'setCacheKeys']);
    });

    it('logs error but still returns response when IDB write fails', async () => {
      mockDataManager.initDb.mockRejectedValue(new Error('IDB write failed'));
      axios.get.mockResolvedValue({ data: { payload: [{ id: 1 }] } });

      const consoleSpy = vi
        .spyOn(console, 'error')
        .mockImplementation(() => {});
      const result = await client.refetchAndCommit('key');

      expect(result.data.payload).toEqual([{ id: 1 }]);
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('refetchAndCommit IDB write failed'),
        expect.any(Error)
      );
      consoleSpy.mockRestore();
    });
  });
});
