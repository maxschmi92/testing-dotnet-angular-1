import { test, expect } from '@playwright/test';

// Smoke test — the app boots and renders its todo widget. Does not require the
// backend (the list shows an empty state if the API is unreachable).
test('admin panel loads with the todo widget', async ({ page }) => {
  await page.goto('/');

  await expect(page.locator('h1')).toHaveText('Admin panel');
  await expect(
    page.getByRole('heading', { name: 'Admin todos' }),
  ).toBeVisible();
  await expect(page.getByPlaceholder('New todo')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Add' })).toBeVisible();
});
