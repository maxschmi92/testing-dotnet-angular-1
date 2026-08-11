using Api.Data;
using Api.Endpoints;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// OpenAPI document — the contract the frontend TS client is generated from (M3).
builder.Services.AddOpenApi();

// EF Core / PostgreSQL. Connection string comes from configuration:
// appsettings holds a local-dev default; containers/CI override via
// the ConnectionStrings__Default environment variable.
var connectionString = builder.Configuration.GetConnectionString("Default");
builder.Services.AddDbContext<AppDbContext>(options => options.UseNpgsql(connectionString));

builder.Services.AddHealthChecks().AddDbContextCheck<AppDbContext>("database");

// CORS. Origins are configurable (Cors:Origins); defaults cover the two Angular
// dev servers. In the cloud the SPAs (Azure Static Web Apps) call the API
// (Azure Container Apps) cross-origin, so the deployment sets Cors__Origins__N
// to the Static Web App URLs.
const string CorsPolicy = "spa";
var corsOrigins =
    builder.Configuration.GetSection("Cors:Origins").Get<string[]>()
    ?? ["http://localhost:4200", "http://localhost:4201"];
builder.Services.AddCors(options =>
    options.AddPolicy(
        CorsPolicy,
        policy => policy.WithOrigins(corsOrigins).AllowAnyHeader().AllowAnyMethod()
    )
);

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

// Applied in every environment: the browser needs CORS headers whenever the SPA
// origin differs from the API origin (always the case in the Azure deployment).
app.UseCors(CorsPolicy);

// Apply pending migrations on startup for Development and when explicitly opted in
// (e.g. the container stack sets ApplyMigrations=true). Skipped under the Testing
// environment so integration tests control their own schema.
if (
    !app.Environment.IsEnvironment("Testing")
    && (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("ApplyMigrations"))
)
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.Migrate();
}

app.MapHealthChecks("/health");
app.MapTodoEndpoints();

app.Run();

// Exposed so the integration test project (WebApplicationFactory) can reference the entry point.
public partial class Program { }
