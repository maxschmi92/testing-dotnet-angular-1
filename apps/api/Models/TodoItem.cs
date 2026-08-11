namespace Api.Models;

/// <summary>
/// Minimal sample entity used to prove the end-to-end DB path (EF Core → Postgres).
/// Replace/extend with real domain models in later milestones.
/// </summary>
public class TodoItem
{
    public int Id { get; set; }

    public required string Title { get; set; }

    public bool IsDone { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
