import { HttpInterceptorFn } from '@angular/common/http';
import { InjectionToken, inject } from '@angular/core';

/**
 * Absolute base URL for the API (e.g. `https://api.…azurecontainerapps.io`).
 *
 * Empty by default, which keeps requests relative (`/api/…`) so the dev proxy
 * and the containerized nginx resolve them same-origin. In the Azure deployment
 * the SPAs are served from Static Web Apps and call the API on Container Apps,
 * so `main.ts` loads the value at runtime from `config.json` and provides it here.
 */
export const API_BASE_URL = new InjectionToken<string>('API_BASE_URL', {
  factory: () => '',
});

/**
 * Prefixes API requests with {@link API_BASE_URL} when one is configured.
 * No-ops when the base is empty, so local/dev/container behaviour is unchanged.
 */
export const apiBaseUrlInterceptor: HttpInterceptorFn = (req, next) => {
  const base = inject(API_BASE_URL);
  if (base && req.url.startsWith('/api')) {
    return next(req.clone({ url: base.replace(/\/$/, '') + req.url }));
  }
  return next(req);
};
