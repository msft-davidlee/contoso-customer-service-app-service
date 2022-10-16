# Contoso Customer Service App Service

This project implements the [Contoso Customer Service Rewards Lookup & Consumption Application](https://github.com/msft-davidlee/contoso-customer-service-app#readme) as a PaaS service using Azure App Service.

## Disclaimer

The information contained in this README.md file and any accompanying materials (including, but not limited to, scripts, sample codes, etc.) are provided "AS-IS" and "WITH ALL FAULTS." Any estimated pricing information is provided solely for demonstration purposes and does not represent final pricing and Microsoft assumes no liability arising from your use of the information. Microsoft makes NO GUARANTEES OR WARRANTIES OF ANY KIND, WHETHER EXPRESSED OR IMPLIED, in providing this information, including any pricing information.

## Get Started

Follow the steps below to create this demo.

1. [Fork](https://docs.github.com/en/get-started/quickstart/fork-a-repo) this git repo.
2. Follow the [governance](https://github.com/msft-davidlee/contoso-governance) which will allow you to create a service principal and have the correct role assignment to the app-service specified resource groups.
3. Follow the [networking](https://github.com/msft-davidlee/contoso-networking) steps to create the networks.
4. Follow the [application](https://github.com/msft-davidlee/contoso-customer-service-app) steps to create application artifacts.
5. Create 2 environments, prod and dev and create a secret PREFIX which is used to name your resources with in each environment.
6. Before running the GitHub workflow, you should review the options below.
7. To teardown your environment, run ``` .\Deployment\RemoveDevResources.ps1 -ArdSolutionId app-service-demo ```

### Deploying directly without a proxy

1. Run GitHub workflow.

### Deploying Azure Application Gateway

Follow the steps below if you want to have Azure Application Gateway as part of your demo.

1. Register a domain name.
2. Create 1 sub-domain name for the customer service app with an A record pointing to the public IP. Use the following command to lookup the public IP ``` $list = (az resource list --tag ard-solution-id=networking-pri | ConvertFrom-Json); $ip = $list | Where-Object { $_.type -eq "microsoft.network/publicipaddresses" }; az network public-ip show --ids $ip.id --query "ipAddress" -o tsv ```
3. Create a SSL certifcate for your sub-domain name. There is a free option using [Let’s Encrypt](https://letsencrypt.org/).
4. Upload the SSL certifcate into your shared Azure Key Vault instance created as part of the [governance](https://github.com/msft-davidlee/contoso-governance) setup step. Name the cert appgwcert.
5. Enable Azure Application Gateway deployment option in your shared Azure App Configuration created as part of the [governance](https://github.com/msft-davidlee/contoso-governance) setup step. Use key ``` contoso-customer-service-app-service/deployment-flags/enable-app-gateway ``` with 2 labels dev or prod and value of true to create or false to disable.
6. Review this [setup step](https://learn.microsoft.com/en-us/azure/application-gateway/configure-web-app?tabs=customdomain%2Cazure-portal) and follow the custom domain recommendation. TL;DR: Ensure your customer service app is configured with your sub-domain name, and upload your SSL cert there as well. This means both your Application Gateway and customer service app are configured with the same domain name.
7. Ensure your AAD App Registration is configured with this sub-domain name. Be sure to append /signin-odic as part of the path.

#### Troubleshooting

1. It may take several minutes before health check is completed. Please review health checks on both App Service and Application Gateway before initiaing the demo.

### Deploying Frontdoor

If you are deploying Frontdoor. Frontdoor by already has its domain name with SSL cert and that's what we will be using. 

After that, in the App Configuration, you will need to configure the follow to enable Frontdoor.

| Name | Comments |
| --- | --- |
| Key | contoso-customer-service-app-service/deployment-flags/enable-frontdoor |
| Label | dev or prod |
| Value | true or false |

### Deploying APIM

In the App Configuration, you will need to configure the follow to enable APIM.

| Name | Comments |
| --- | --- |
| Key | contoso-customer-service-app-service/deployment-flags/enable-apim |
| Label | dev or prod |
| Value | true or false |

## Have an issue?

You are welcome to create an issue if you need help but please note that there is no timeline to answer or resolve any issues you have with the contents of this project. Use the contents of this project at your own risk! If you are interested to volunteer to maintain this, please feel free to reach out to be added as a contributor and send Pull Requests.
