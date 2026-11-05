# Secrets and variables

The deployment authenticates to Azure with OpenID Connect (federated credentials). No client secrets are stored in GitHub.

The variables are set per [repository environment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) (`dev` and `prd`).

| Variable name            | Description                                                        |
|--------------------------|--------------------------------------------------------------------|
| `AZURE_SP_CLIENT_ID`     | Client ID of the deployment app registration for the subscription. |
| `AZURE_TENANT_ID`        | Entra ID tenant ID.                                                |
| `AZURE_SUBSCRIPTION_ID`  | ID of the subscription to deploy to.                               |
| `AZURE_SUBSCRIPTION_URL` | Link to the subscription in the Azure portal.                      |

## Federated credentials

Each subscription has one deployment app registration (e.g. `sp-analogio-prd-ghac`) with the Owner role on the subscription. The other AnalogIO repositories that deploy to the subscription use the same app registration. Each repository and environment has its own federated credential on it.

The subject uses the immutable owner and repository IDs:

```txt
repo:AnalogIO@<owner-id>/<repo>@<repo-id>:environment:<environment>
```

Get the IDs with `gh api repos/AnalogIO/<repo> --jq '"\(.owner.id) \(.id)"'`.

Add a federated credential:

```sh
az ad app federated-credential create --id <AZURE_SP_CLIENT_ID> --parameters '{
  "name": "ghac-azure-prd",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:AnalogIO@7061408/azure@540876919:environment:prd",
  "audiences": ["api://AzureADTokenExchange"]
}'
```
