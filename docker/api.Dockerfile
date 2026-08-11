# syntax=docker/dockerfile:1
# Multi-stage build for the .NET Web API.
# Context is the repo root (see docker-compose.yml).

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
# Restore first (better layer caching) — the API project has no in-repo project refs.
COPY global.json ./
COPY apps/api/Api.csproj apps/api/
RUN dotnet restore apps/api/Api.csproj
# Then the sources and publish. The build-time OpenAPI emission is disabled here
# (the container doesn't need the spec file, and it keeps publish self-contained).
COPY apps/api/ apps/api/
RUN dotnet publish apps/api/Api.csproj -c Release -o /app \
    /p:UseAppHost=false /p:OpenApiGenerateDocumentsOnBuild=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
COPY --from=build /app ./
EXPOSE 8080
ENTRYPOINT ["dotnet", "Api.dll"]
