# Azure infrastructure (POC)

## Resouce naming convention

Per Azure Cloud Adaptation Framework (CAF), we follow a defined resource naming convention to have a uniform way of naming resources. All resources will follow the below structure

```txt
<resource-type>-<organization>-<application>-<environment>
```

- `<resource-type>` An abbreviation that represents the type of Azure resource. See [Recommended abbreviations for Azure resource types](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations).
- `organization` Top-level name of organization to ensure uniqueness of resources which have a global resource name. Use `aio`.
- `<application>` Application, or service that the resource is a part of. For shared resources, `shr` is used.
- `<environment>` The stage of the development lifecycle for the workload that the resource supports. Use `dev` or `prd`.

## App Service plan scaling function

The function app in `functions/AppServicePlanScaling` scales the App Service plan between a peak and an off-peak SKU. It runs every hour at 15 minutes past the hour (UTC), works out the expected SKU from the local time in `Scaling__TimeZone`, and scales the plan only if its SKU is different. Peak hours are Monday to Friday, from `Scaling__PeakStartHour` until `Scaling__PeakEndHour`.

| Setting                   | Default             | Description                                                    |
|---------------------------|---------------------|----------------------------------------------------------------|
| `Scaling__PlanResourceId` |                     | Resource ID of the App Service plan. Required.                 |
| `Scaling__TimeZone`       | `Europe/Copenhagen` | Time zone of the peak hours.                                   |
| `Scaling__PeakStartHour`  | `7`                 | Local hour when the plan is scaled up.                         |
| `Scaling__PeakEndHour`    | `16`                | Local hour when the plan is scaled down.                       |
| `Scaling__PeakSku`        | `B2`                | SKU in peak hours.                                             |
| `Scaling__OffPeakSku`     | `B1`                | SKU outside peak hours. Must have the same tier as `PeakSku`.  |
| `Scaling__DryRun`         | `false`             | If `true`, log the change but do not scale the plan.           |

### Run locally

Requirements:

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local), e.g. `brew tap azure/functions && brew install azure-functions-core-tools@4`
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- Docker, for the Azurite storage emulator. The timer trigger needs storage.

1. Sign in to Azure. The function uses your Azure CLI sign-in. You need at least the Reader role on the App Service plan for a dry run.

   ```sh
   az login
   ```

2. Create `local.settings.json` and set `Scaling__PlanResourceId`. Keep `Scaling__DryRun` set to `true`, unless you intend to scale the plan.

   ```sh
   cd functions/AppServicePlanScaling
   cp local.settings.example.json local.settings.json
   az appservice plan show -g rg-aio-shr-dev -n asp-aio-shr-dev --query id -o tsv
   ```

3. Start Azurite and the function app.

   ```sh
   docker compose up -d
   func start
   ```

4. The timer runs only at 15 minutes past the hour. To run the function now, call the admin endpoint from another terminal. The output shows in the `func start` terminal.

   ```sh
   curl -X POST http://localhost:7071/admin/functions/ScalePlan \
     -H 'Content-Type: application/json' -d '{}'
   ```

Stop Azurite with `docker compose down`.
