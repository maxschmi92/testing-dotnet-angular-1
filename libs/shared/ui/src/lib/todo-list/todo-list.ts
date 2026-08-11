import {
  ChangeDetectionStrategy,
  Component,
  input,
  output,
} from '@angular/core';

/**
 * Minimal shape this presentational component needs. Kept local so `shared/ui`
 * stays generic and does not depend on `shared/data-access`.
 */
export interface TodoListItem {
  id?: number | string;
  title: string;
  isDone?: boolean;
}

/**
 * Presentational todo list. Renders items and emits `add` when the user submits
 * a new title — it holds no data-access logic of its own.
 */
@Component({
  selector: 'lib-todo-list',
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './todo-list.html',
  styleUrl: './todo-list.scss',
})
export class TodoList {
  readonly heading = input('Todos');
  readonly todos = input.required<TodoListItem[]>();
  readonly loading = input(false);

  readonly add = output<string>();

  protected submit(title: string): void {
    const trimmed = title.trim();
    if (trimmed) {
      this.add.emit(trimmed);
    }
  }
}
