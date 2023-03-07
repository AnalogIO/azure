# Secrets and variables

| Variable name       	| Description                                                                          	|
|---------------------	|--------------------------------------------------------------------------------------	|
| `AZURE_CREDENTIALS` 	| Azure Service Principal credentials. Service Principal is created per subscription.  	|

## Create Service Principal

Service Principals are created using AZ CLI. The full JSON object outputted by the command is added as a secret for the respective [repository environment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#environment-secrets).

Generate service princpal

```powershell
az ad sp create-for-rbac --name "sp-analogio-dev-ghac" --role Owner \
                         --scopes /subscriptions/{subscription-id} \
                         --sdk-auth
```
