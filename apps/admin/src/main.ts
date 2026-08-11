import { bootstrapApplication } from '@angular/platform-browser';
import { API_BASE_URL } from '@angular-dotnet/data-access';
import { appConfig } from './app/app.config';
import { App } from './app/app';

// Load the per-environment API base URL at runtime (empty in dev/containers →
// relative `/api`; the Static Web App serves a config.json with the Container
// Apps URL in production). Kept out of the build so one artifact fits any env.
fetch('config.json')
  .then((res) => (res.ok ? res.json() : { apiBaseUrl: '' }))
  .catch(() => ({ apiBaseUrl: '' }))
  .then((cfg: { apiBaseUrl?: string }) =>
    bootstrapApplication(App, {
      ...appConfig,
      providers: [
        ...appConfig.providers,
        { provide: API_BASE_URL, useValue: cfg.apiBaseUrl ?? '' },
      ],
    }),
  )
  .catch((err) => console.error(err));
