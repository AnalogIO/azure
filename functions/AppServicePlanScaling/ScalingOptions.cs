using System.ComponentModel.DataAnnotations;

namespace AppServicePlanScaling;

public class ScalingOptions
{
    public const string SectionName = "Scaling";

    [Required]
    public required string PlanResourceId { get; init; }

    public string TimeZone { get; init; } = "Europe/Copenhagen";

    [Range(0, 23)]
    public int PeakStartHour { get; init; } = 7;

    [Range(1, 24)]
    public int PeakEndHour { get; init; } = 16;

    public string PeakSku { get; init; } = "B2";

    public string OffPeakSku { get; init; } = "B1";

    public bool DryRun { get; init; }
}
