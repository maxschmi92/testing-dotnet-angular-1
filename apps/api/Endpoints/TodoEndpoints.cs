using Api.Data;
using Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Api.Endpoints;

/// <summary>
/// Minimal Todo endpoints — a thin sample surface to prove the DB round-trip and
/// give the frontend something typed to consume. Replace with real features later.
/// </summary>
public static class TodoEndpoints
{
    public static IEndpointRouteBuilder MapTodoEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/todos").WithTags("Todos");

        group
            .MapGet(
                "/",
                async (AppDbContext db) =>
                    await db.Todos.OrderByDescending(t => t.CreatedAt).ToListAsync()
            )
            .WithName("GetTodos");

        group
            .MapGet(
                "/{id:int}",
                async (int id, AppDbContext db) =>
                    await db.Todos.FindAsync(id) is TodoItem todo
                        ? Results.Ok(todo)
                        : Results.NotFound()
            )
            .WithName("GetTodoById");

        group
            .MapPost(
                "/",
                async (CreateTodoRequest request, AppDbContext db) =>
                {
                    var todo = new TodoItem { Title = request.Title };
                    db.Todos.Add(todo);
                    await db.SaveChangesAsync();
                    return Results.Created($"/api/todos/{todo.Id}", todo);
                }
            )
            .WithName("CreateTodo");

        return app;
    }
}

/// <summary>Payload for creating a <see cref="TodoItem" />.</summary>
public record CreateTodoRequest(string Title);
