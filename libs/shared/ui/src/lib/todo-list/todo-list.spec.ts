import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TodoList } from './todo-list';

describe('TodoList', () => {
  let fixture: ComponentFixture<TodoList>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TodoList],
    }).compileComponents();
    fixture = TestBed.createComponent(TodoList);
    fixture.componentRef.setInput('todos', []);
    fixture.detectChanges();
  });

  it('renders the empty state', () => {
    const text = (fixture.nativeElement as HTMLElement).textContent ?? '';
    expect(text).toContain('No todos yet');
  });

  it('emits add with a trimmed title', () => {
    let emitted: string | undefined;
    fixture.componentInstance.add.subscribe((title) => (emitted = title));

    const host = fixture.nativeElement as HTMLElement;
    const input = host.querySelector('input');
    const form = host.querySelector('form');
    expect(input).not.toBeNull();
    expect(form).not.toBeNull();

    (input as HTMLInputElement).value = '  write tests  ';
    (form as HTMLFormElement).dispatchEvent(new Event('submit'));

    expect(emitted).toBe('write tests');
  });
});
