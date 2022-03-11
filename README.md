# Disclaimer
The information contained in this README.md file and any accompanying materials (including, but not limited to, scripts, sample codes, etc.) are provided "AS-IS" and "WITH ALL FAULTS." Any estimated pricing information is provided solely for demonstration purposes and does not represent final pricing and Microsoft assumes no liability arising from your use of the information. Microsoft makes NO GUARANTEES OR WARRANTIES OF ANY KIND, WHETHER EXPRESSED OR IMPLIED, in providing this information, including any pricing information.

# Introduction
This project implements the Contoso Customer Service Rewards Lookup & Consumption Application with PaaS service. For more information about this workload, checkout: https://github.com/msft-davidlee/contoso-customer-service-app#readme. 

# Get Started
To create this, you will need to follow build the application. The applications are build via a process on the [source repo](https://github.com/msft-davidlee/contoso-customer-service-app) and deploy to [shared services](https://github.com/msft-davidlee/az-internal-shared-services). Please review both as pre-reqs project before proceeding further here. Next, use your Azure subscription and also a AAD instance that you control and follow the steps below.

1. Fork this git repo. See: https://docs.github.com/en/get-started/quickstart/fork-a-repo
2. Create two resource groups to represent two environments. Suffix each resource group name with either a -dev or -prod. An example could be todo-dev and todo-prod.
3. Next, you must create a service principal with Contributor roles assigned to the two resource groups.
4. In your github organization for your project, create two environments, and named them dev and prod respectively.
5. Create the following secrets in your github per environment. Be sure to populate with your desired values. The values below are all suggestions.
6. Note that the environment suffix of dev or prod will be appened to your resource group but you will have the option to define your own resource prefix.
7. Create App Registration include the appropriate Urls. See Secrets below.

## Deploying Azure Application Gateway
If you are deploying Azure Application Gateway, you will need to generate an SSL certifcate for demo.contoso.com. Use the Setup/CreateCert.ps1 to do that. Run that script as an Administrator. Note the password. After that, upload that Cert into Azure Key Vault and also store the password as a secret for your own reference. 

After that, in the App Configuration, you will need to configure the follow to enable Azure Application Gateway.
| Name | Comments |
| --- | --- |
| Key | contoso-customer-service-app-service/deployment-flags/enable-app-gateway |
| Label | dev or prod |
| Value | true or false |

Lastly, you will want to update your host file with the IP assigned to the Application Gateway so you can launch https://demo.contoso.com.

## Secrets
| Name | Comments |
| --- | --- |
| MS_AZURE_CREDENTIALS | <pre>{<br/>&nbsp;&nbsp;&nbsp;&nbsp;"clientId": "",<br/>&nbsp;&nbsp;&nbsp;&nbsp;"clientSecret": "", <br/>&nbsp;&nbsp;&nbsp;&nbsp;"subscriptionId": "",<br/>&nbsp;&nbsp;&nbsp;&nbsp;"tenantId": "" <br/>}</pre> |
| PREFIX | mytodos - or whatever name you would like for all your resources |
| RESOURCE_GROUP | appservice - or whatever name you give to the resource group |

## Have an issue?
You are welcome to create an issue if you need help but please note that there is no timeline to answer or resolve any issues you have with the contents of this project. Use the contents of this project at your own risk! If you are interested to volunteer to maintain this, please feel free to reach out to be added as a contributor and send Pull Requests (PR).