import fromUnixTime from 'date-fns/fromUnixTime';
import differenceInDays from 'date-fns/differenceInDays';
import Cookies from 'js-cookie';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import { LocalStorage } from 'shared/helpers/localStorage';
import SessionStorage from 'shared/helpers/sessionStorage';
import { emitter } from 'shared/helpers/mitt';
import {
  ANALYTICS_IDENTITY,
  ANALYTICS_RESET,
  CHATWOOT_RESET,
  CHATWOOT_SET_USER,
} from '../../constants/appEvents';

Cookies.defaults = { sameSite: 'Lax', path: '/' };

export const getLoadingStatus = state => state.fetchAPIloadingStatus;
export const setLoadingStatus = (state, status) => {
  state.fetchAPIloadingStatus = status;
};

export const setUser = user => {
  emitter.emit(CHATWOOT_SET_USER, { user });
  emitter.emit(ANALYTICS_IDENTITY, { user });
};

export const getHeaderExpiry = response =>
  fromUnixTime(response.headers.expiry);

export const setAuthCredentials = response => {
  const expiryDate = getHeaderExpiry(response);
  // Extract only the auth headers we need (AxiosHeaders object doesn't stringify properly)
  const authHeaders = {
    'access-token': response.headers['access-token'],
    client: response.headers.client,
    uid: response.headers.uid,
    expiry: response.headers.expiry,
  };
  Cookies.set('cw_d_session_info', JSON.stringify(authHeaders), {
    expires: differenceInDays(expiryDate, new Date()),
    path: '/',
  });
  setUser(response.data.data, expiryDate);
};

export const clearBrowserSessionCookies = () => {
  Cookies.remove('cw_d_session_info', { path: '/' });
  Cookies.remove('auth_data', { path: '/' });
  Cookies.remove('user', { path: '/' });
};

export const clearLocalStorageOnLogout = () => {
  // Clear unscoped keys (legacy) — LocalStorage.remove also removes the :ts key
  LocalStorage.remove(LOCAL_STORAGE_KEYS.DRAFT_MESSAGES);
  LocalStorage.remove(LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO);

  // Clear account-scoped keys
  const keysToClean = [
    LOCAL_STORAGE_KEYS.DRAFT_MESSAGES,
    LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO,
    'ai_backend_onboarding_current_step',
  ];
  const allKeys = Object.keys(window.localStorage);
  allKeys
    .filter(key => !key.endsWith(':ts'))
    .forEach(key => {
      if (keysToClean.some(prefix => key.startsWith(`${prefix}::`))) {
        LocalStorage.remove(key);
      }
    });
};

export const clearSessionStorageOnLogout = () => {
  SessionStorage.remove(SESSION_STORAGE_KEYS.IMPERSONATION_USER);
};

export const deleteIndexedDBOnLogout = async () => {
  let dbs = [];
  try {
    dbs = await window.indexedDB.databases();
    dbs = dbs.map(db => db.name);
  } catch (e) {
    dbs = JSON.parse(localStorage.getItem('cw-idb-names') || '[]');
  }

  dbs.forEach(dbName => {
    const deleteRequest = window.indexedDB.deleteDatabase(dbName);

    deleteRequest.onerror = event => {
      // eslint-disable-next-line no-console
      console.error(`Error deleting database ${dbName}.`, event);
    };

    deleteRequest.onsuccess = () => {
      // eslint-disable-next-line no-console
      console.log(`Database ${dbName} deleted successfully.`);
    };
  });

  localStorage.removeItem('cw-idb-names');
};

export const clearCookiesOnLogout = () => {
  emitter.emit(CHATWOOT_RESET);
  emitter.emit(ANALYTICS_RESET);
  clearBrowserSessionCookies();
  clearLocalStorageOnLogout();
  clearSessionStorageOnLogout();
  const globalConfig = window.globalConfig || {};
  const logoutRedirectLink = globalConfig.LOGOUT_REDIRECT_LINK || '/';
  window.location = logoutRedirectLink;
};

export const parseAPIErrorResponse = error => {
  if (error?.response?.data?.message) {
    return error?.response?.data?.message;
  }
  if (error?.response?.data?.error) {
    return error?.response?.data?.error;
  }
  if (error?.response?.data?.errors) {
    return error?.response?.data?.errors[0];
  }
  return error;
};

export const throwErrorMessage = error => {
  const errorMessage = parseAPIErrorResponse(error);
  throw new Error(errorMessage);
};

export const parseLinearAPIErrorResponse = (error, defaultMessage) => {
  const errorData = error.response.data;
  const errorMessage = errorData?.error?.errors?.[0]?.message || defaultMessage;
  return errorMessage;
};
