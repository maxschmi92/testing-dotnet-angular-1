import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
} from '@angular/core';
import { ApiV1Service, TodoItem } from '@angular-dotnet/data-access';
import { TodoList } from '@angular-dotnet/ui';

@Component({
  selector: 'app-root',
  imports: [TodoList],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {
  private readonly api = inject(ApiV1Service);

  protected readonly todos = signal<TodoItem[]>([]);
  protected readonly loading = signal(true);

  constructor() {
    this.reload();
  }

  protected reload(): void {
    this.loading.set(true);
    this.api.getTodos().subscribe({
      next: (todos) => {
        this.todos.set(todos);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  protected addTodo(title: string): void {
    this.api.createTodo({ title }).subscribe(() => this.reload());
  }
}
