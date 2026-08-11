using System.Net;
using System.Net.Http.Json;
using Api.Models;

namespace Api.Tests;

/// <summary>
/// Integration tests over the real HTTP pipeline (WebApplicationFactory) with an
/// in-memory database. Exercises the health check and the Todo endpoints.
/// </summary>
public class TodoEndpointsTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Health_ReturnsHealthy()
    {
        var response = await _client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task PostThenGet_RoundTripsTheTodo()
    {
        var create = await _client.PostAsJsonAsync("/api/todos", new { title = "integration" });
        Assert.Equal(HttpStatusCode.Created, create.StatusCode);

        var created = await create.Content.ReadFromJsonAsync<TodoItem>();
        Assert.NotNull(created);
        Assert.Equal("integration", created!.Title);
        Assert.False(created.IsDone);

        var todos = await _client.GetFromJsonAsync<List<TodoItem>>("/api/todos");
        Assert.NotNull(todos);
        Assert.Contains(todos!, t => t.Title == "integration");
    }
}
