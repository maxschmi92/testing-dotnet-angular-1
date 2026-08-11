import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import {
  provideHttpClientTesting,
  HttpTestingController,
} from '@angular/common/http/testing';
import { ApiV1Service } from './generated/api.service';

/**
 * Smoke tests for the generated OpenAPI client — verifies the methods hit the
 * expected relative routes (which the dev proxy / nginx forward to the API).
 */
describe('ApiV1Service (generated client)', () => {
  let service: ApiV1Service;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(ApiV1Service);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('getTodos issues GET /api/todos', () => {
    service.getTodos().subscribe();
    const req = http.expectOne('/api/todos');
    expect(req.request.method).toBe('GET');
    req.flush([]);
  });

  it('createTodo issues POST /api/todos with the payload', () => {
    service.createTodo({ title: 'write tests' }).subscribe();
    const req = http.expectOne('/api/todos');
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({ title: 'write tests' });
    req.flush({});
  });
});
