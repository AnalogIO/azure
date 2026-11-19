using Azure;
using Azure.Core;
using Azure.ResourceManager;
using Azure.ResourceManager.AppService;
using Azure.ResourceManager.Resources;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace AppServicePlanScaling;

public class ScalePlan(
    ArmClient armClient,
    TimeProvider timeProvider,
    IOptions<ScalingOptions> options,
    ILogger<ScalePlan> logger
)
{
    [Function(nameof(ScalePlan))]
    public async Task Run(
        [TimerTrigger("0 15 * * * *")] TimerInfo timer,
        CancellationToken cancellationToken
    )
    {
        var settings = options.Value;
        DateTimeOffset now = TimeZoneInfo.ConvertTimeBySystemTimeZoneId(
            timeProvider.GetUtcNow(),
            settings.TimeZone
        );
        var desiredSku = IsPeak(now, settings) ? settings.PeakSku : settings.OffPeakSku;

        var planId = new ResourceIdentifier(settings.PlanResourceId);
        AppServicePlanResource plan = await armClient
            .GetAppServicePlanResource(planId)
            .GetAsync(cancellationToken);
        var currentSku = plan.Data.Sku.Name;

        if (currentSku == desiredSku)
        {
            logger.LogInformation(
                "App Service plan {Plan} is {Sku} at {LocalTime}. No change",
                planId.Name,
                currentSku,
                now
            );
            return;
        }

        if (settings.DryRun)
        {
            logger.LogInformation(
                "Dry run: would scale App Service plan {Plan} from {CurrentSku} to {DesiredSku} at {LocalTime}",
                planId.Name,
                currentSku,
                desiredSku,
                now
            );
            return;
        }

        logger.LogInformation(
            "Scaling App Service plan {Plan} from {CurrentSku} to {DesiredSku} at {LocalTime}",
            planId.Name,
            currentSku,
            desiredSku,
            now
        );
        
        var data = plan.Data;
        data.Sku.Name = desiredSku;
        data.Sku.Size = desiredSku;

        var resourceGroup = armClient.GetResourceGroupResource(
            ResourceGroupResource.CreateResourceIdentifier(
                planId.SubscriptionId,
                planId.ResourceGroupName
            )
        );
        await resourceGroup
            .GetAppServicePlans()
            .CreateOrUpdateAsync(WaitUntil.Completed, planId.Name, data, cancellationToken);
    }

    private static bool IsPeak(DateTimeOffset localTime, ScalingOptions settings) =>
        localTime.DayOfWeek is not (DayOfWeek.Saturday or DayOfWeek.Sunday)
        && localTime.Hour >= settings.PeakStartHour
        && localTime.Hour < settings.PeakEndHour;
}
