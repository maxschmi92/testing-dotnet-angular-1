using Api.Models;

namespace Api.Tests;

/// <summary>
/// Plain unit test (no DB) — a representative smoke test for the domain model.
/// Integration tests using WebApplicationFactory + Postgres are added in M5.
/// </summary>
public class TodoItemTests
{
    [Fact]
    public void NewTodo_DefaultsToNotDone()
    {
        var todo = new TodoItem { Title = "write tests" };

        Assert.False(todo.IsDone);
        Assert.Equal("write tests", todo.Title);
    }
}
