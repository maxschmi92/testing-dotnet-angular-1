using Api.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Api.Tests;

/// <summary>
/// Boots the real API in-process (full HTTP pipeline + endpoints) but swaps the
/// Npgsql DbContext for an in-memory one, so integration tests need no Postgres.
/// The "Testing" environment also disables the startup migration in Program.
/// A Testcontainers-backed Postgres variant can be added later.
/// </summary>
public class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureServices(services =>
        {
            // Drop the app's Npgsql DbContext registrations.
            var toRemove = services
                .Where(d =>
                    d.ServiceType == typeof(DbContextOptions<AppDbContext>)
                    || d.ServiceType == typeof(DbContextOptions)
                    || (d.ServiceType.FullName?.Contains("AppDbContext") ?? false)
                )
                .ToList();
            foreach (var descriptor in toRemove)
            {
                services.Remove(descriptor);
            }

            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase("api-integration-tests")
            );
        });
    }
}
