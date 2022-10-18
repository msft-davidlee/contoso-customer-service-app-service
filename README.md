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
7. To teardown your solution, run ``` .\RemoveSolution.ps1 -ArdSolutionId app-service-demo -ArdEnvironment <either dev or prod> ```

### Deploying directly without a proxy

1. Run GitHub workflow.

### Deploying Azure Application Gateway

Follow the steps below if you want to have Azure Application Gateway as part of your demo. You should NOT deploy Azure Front Door in this setup.

1. Register a domain name.
2. Create a sub-domain name for the customer service app with an A record pointing to the public IP. Use the following command to lookup the public IP ``` $list = (az resource list --tag ard-solution-id=networking-pri | ConvertFrom-Json); $ip = $list | Where-Object { $_.type -eq "microsoft.network/publicipaddresses" }; az network public-ip show --ids $ip.id --query "ipAddress" -o tsv ```
3. Create a SSL certifcate for your sub-domain name. There is a free option using [Let’s Encrypt](https://letsencrypt.org/).
4. Upload the SSL certifcate into your shared Azure Key Vault instance created as part of the [governance](https://github.com/msft-davidlee/contoso-governance) setup step. Name the cert appgwcert.
5. Enable Azure Application Gateway deployment option in your shared Azure App Configuration created as part of the [governance](https://github.com/msft-davidlee/contoso-governance) setup step. Use key ``` contoso-customer-service-app-service/deployment-flags/enable-app-gateway ``` with 2 labels dev or prod and value of true to create or false to disable.
6. Run GitHub Workflow
7. Review this [setup step](https://learn.microsoft.com/en-us/azure/application-gateway/configure-web-app?tabs=customdomain%2Cazure-portal) and follow the custom domain recommendation. TL;DR: Ensure your customer service app is configured with your sub-domain name, and upload your SSL cert there as well. This means both your Application Gateway and customer service app are configured with the same domain name.
8. Ensure your AAD App Registration is configured with this sub-domain name. Be sure to append /signin-odic as part of the path.

#### Troubleshooting Azure Application Gateway Deployment

1. It may take several minutes before health check is completed. Please review health checks on both App Service and Application Gateway before initiaing the demo.
2. If the Application Gateway continues to be unhealthy after you have configured the customer service app, you may need to reset the health probe of the Application Gateway by performing a save on the Application Gateway settings.

### Deploying Azure Front Door

Follow the steps below if you want to have Azure Front Door as part of your demo. You should NOT deploy Azure Application Gateway in this setup.

1. Register a domain name.
2. Enable Azure Front Door deployment option in your shared Azure App Configuration created as part of the [governance](https://github.com/msft-davidlee/contoso-governance) setup step. Use key ``` contoso-customer-service-app-service/deployment-flags/enable-frontdoor ``` with 2 labels dev or prod and value of true to create or false to disable.
3. Run GitHub Workflow
4. Create a SSL certifcate for your sub-domain name. There is a free option using [Let’s Encrypt](https://letsencrypt.org/).
5. Create a sub-domain name for the customer service app with CNAME pointing to [frontdoor](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-custom-domain). Choose Certificate management type as Front Door managed (do not attempt to use your existing SSL cert you generated, it will be used later). For more information, see [this](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-custom-domain-https#option-1-default-use-a-certificate-managed-by-front-door).
6. Update the routing rule for contoso-customer-app-routing and use the new frontend you have created.
7. Update backend pools with the hostname as the sub-domain name. Be sure to save all changes.
8. Ensure your customer service app is configured with your sub-domain name, and upload your SSL cert there as well. This means both your Frontdoor and customer service app are configured with the same domain name.

#### Troubleshooting Azure Front Door Deployment

1. It may take up to an hour before SSL certificate is issued by Azure Front Door on your custom domain name. Make sure an SSL certificate is issued before you proceed with the demo.

### Deploying APIM

1. Enable APIM deployment option in your shared Azure App Configuration created as part of the [governance](https://github.com/msft-davidlee/contoso-governance) setup step. Use key ``` contoso-customer-service-app-service/deployment-flags/enable-apim ``` with 2 labels dev or prod and value of true to create or false to disable.
2. Run GitHub Workflow
3. Import the Test\Contoso Customer Service Member API.postman_collection.json into Postman
4. Create the following environment variables

    * ClientId: See App Registration in AAD
    * ClientSecret: See App Registration in AAD
    * TenantId: See AAD properties
    * SubscriptionKey: See APIM Built-in all-access subscription for key
    * apiName: See APIM instance name
5. Run postman collection.

## Have an issue?

You are welcome to create an issue if you need help but please note that there is no timeline to answer or resolve any issues you have with the contents of this project. Use the contents of this project at your own risk! If you are interested to volunteer to maintain this, please feel free to reach out to be added as a contributor and send Pull Requests.
