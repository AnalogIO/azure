using AppServicePlanScaling;
using Azure.Identity;
using Azure.ResourceManager;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = FunctionsApplication.CreateBuilder(args);

builder
    .Services.AddApplicationInsightsTelemetryWorkerService()
    .ConfigureFunctionsApplicationInsights();

builder.Services.AddSingleton(new ArmClient(new DefaultAzureCredential()));
builder.Services.AddSingleton(TimeProvider.System);

builder
    .Services.AddOptions<ScalingOptions>()
    .BindConfiguration(ScalingOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Build().Run();
