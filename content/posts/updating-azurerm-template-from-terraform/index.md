---
title: "Updating AzureRM templates from Terraform"
date: 2021-05-19
tags:
  - azure
  - sqlmi
  - terraform
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Deploying SQL Managed instance using Terraform and
  AzureRM deployment templates
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "flow.png"
    alt: "Diagram of SQL MI creation flow"
    caption: "Resource creation flow"
    relative: true

---

## Summary

I have deployed some Azure SQL Managed Instances using Terraform.  Since
there are no native resources for this service in the Azure provider,
I used an Azure Resource Manager deployment template.  Recently, I had
to add an output to that template (so that another workspace could set
up remote logging), and wanted to note my experience with updating
deployment templates from Terraform.  Here, I'll detail the original
design and then walk through the update process.

## Design

Terraform does not yet have a `azurerm_sql_managed_instance` resource
to manage this service.  See the [PR] or [issue] in the [azure RM
provider][provider] for more information.  As of this writing, this is
over a year old, but it looks like there's been some [recent work][pr2]
on adding this resource.

[pr]: https://github.com/terraform-providers/terraform-provider-azurerm/pull/5399
[pr2]: https://github.com/terraform-providers/terraform-provider-azurerm/pull/11594
[issue]: https://github.com/terraform-providers/terraform-provider-azurerm/issues/1747
[provider]: https://github.com/terraform-providers/terraform-provider-azurerm

For now, we build the managed database infrastructure with a resource manager
template deployed by terraform.  Once Terraform has first-class support for
SQL managed instances, we can import those resources and manage them directly.
All the other related resources are managed by terraform directly.

### Supported resources

#### Resource group

Create a single resource group to for everything in this workspace:

```terraform
resource "azurerm_resource_group" "rg" {
  name     = "${var.location}-sqlmi-${var.environment}"
  location = var.location
}
```

I've omitted any tagging here to keep this post simple, but tagging to
your organization's standards is highly recommended.

#### Security group

Create a security group and associate it with the "sqlmi" subnets.

```terraform
resource "azurerm_network_security_group" "this" {
  name                = "${var.location}-sqlmi-${var.environment}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = data.terraform_remote_state.common.outputs.subnets["sqlmi"].id
  network_security_group_id = azurerm_network_security_group.this.id
}
```

#### Subnet delegations

In this particular situation, the subnet is managed by another workspace
and referenced as a remote state data source.  The relevant portions of
that terraform code:

```terraform
locals {
  # delegations for service subnets
  delegations = {
    sqlmi = {
      sqlmi_delegation = {
        name = "Microsoft.Sql/managedInstances"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
          "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
          "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
        ]
      }
    }
  }
}

resource "azurerm_subnet" "this" {
  for_each             = local.subnet_prefixes
  name                 = "${var.location}-common-${var.environment}-${each.key}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.subnet_prefixes[each.key]]

  dynamic "delegation" {
    for_each = lookup(local.delegations, each.key, {})
    content {
      name = delegation.key
      service_delegation {
        name    = delegation.value.name
        actions = delegation.value.actions
      }
    }
  }
}
```

Managed services such as the Azure SQL Managed Instance require you to
delegate actions so that Azure can automatically update the resource.
This pattern allows us to easily add more of this type of subnet by
updating the `delegations` variable, where the keys match the keys of
the `subnet_prefixes` variable.

#### Security rules

Create default deny rules, and a single rule to permit SQL traffic from
`allowed_prefixes` to the `sqlmi` subnet.

```terraform
resource "azurerm_network_security_rule" "allow_tds_inbound" {
  name                        = "allow_tds_inbound"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["1433", "11000-11999"]
  source_address_prefixes     = var.allowed_prefixes
  destination_address_prefix  = data.terraform_remote_state.common.outputs.subnets["sqlmi"].address_prefix
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.this.name
}
resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "deny_all_inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.this.name
}
resource "azurerm_network_security_rule" "deny_all_outbound" {
  name                        = "deny_all_outbound"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.this.name
}
```

### Deployment template

First, we write the deployment template, `deploy.json`.  This defines
`resources` we want to deploy, in this case a single resource of type
`Microsoft.Sql/managedInstances`; the `parameters` that will be used to
configure that resource; and `outputs`, any computed attributes that we
want to expose to terraform.  Shown here in my editor with the outputs
and parameters [folded][vim-fold] so that you can see the structure at a
glance.

[vim-fold]: http://vimdoc.sourceforge.net/htmldoc/fold.html

![ deploy.json](deploy.json.png#center)

{{< disclose open=false summary="complete deploy.json file" >}}

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "outputs": {
    "fqdn": {
      "type": "string",
      "value": "[reference(parameters('sqlManagedInstanceName')).fullyQualifiedDomainName]"
    },
    "id": {
      "type": "string",
      "value": "[resourceId('Microsoft.Sql/managedInstances', parameters('sqlManagedInstanceName'))]"
    }
  },
  "parameters": {
    "location": {
      "defaultValue": "[resourceGroup().location]",
      "metadata": {
        "description": "Location for all resources"
      },
      "type": "string"
    },
    "sqlManagedInstance-collation": {
      "defaultValue": "SQL_Latin1_General_CP1_CI_AS",
      "metadata": {
        "description": "SQL Collation"
      },
      "type": "string"
    },
    "sqlManagedInstance-hardwareFamily": {
      "allowedValues": [
        "Gen4",
        "Gen5"
      ],
      "defaultValue": "Gen5",
      "metadata": {
        "description": "Hardware family (Gen4, Gen5)"
      },
      "type": "string"
    },
    "sqlManagedInstance-licenseType": {
      "allowedValues": [
        "BasePrice",
        "LicenseIncluded"
      ],
      "defaultValue": "BasePrice",
      "metadata": {
        "description": "Type of license: BasePrice (BYOL) or LicenceIncluded"
      },
      "type": "string"
    },
    "sqlManagedInstance-skuEdition": {
      "allowedValues": [
        "GeneralPurpose",
        "BusinessCritical"
      ],
      "defaultValue": "GeneralPurpose",
      "metadata": {
        "description": "SKU Edition (GeneralPurpose, BusinessCritical) "
      },
      "type": "string"
    },
    "sqlManagedInstance-skuName": {
      "allowedValues": [
        "GP_Gen4",
        "GP_Gen5",
        "BC_Gen4",
        "BC_Gen5"
      ],
      "defaultValue": "GP_Gen5",
      "metadata": {
        "description": "SKU NAME (GP_Gen4, GP_Gen5, BC_GEN5)"
      },
      "type": "string"
    },
    "sqlManagedInstance-storageSizeInGB": {
      "defaultValue": "256",
      "metadata": {
        "description": "Amount of Storage in GB for this instance"
      },
      "type": "string"
    },
    "sqlManagedInstance-vCores": {
      "defaultValue": "8",
      "metadata": {
        "description": "Number of vCores for this instance"
      },
      "type": "string"
    },
    "sqlManagedInstanceAdminLogin": {
      "metadata": {
        "description": "Admin user for Managed Instance"
      },
      "type": "string"
    },
    "sqlManagedInstanceName": {
      "defaultValue": "[concat('managedInstance-', uniqueString(resourceGroup().id))]",
      "metadata": {
        "description": "Name of the Azure SQL Managed Instance - must be globally unique, contain only lowercase letters, numbers and '-'"
      },
      "type": "string"
    },
    "sqlManagedInstancePassword": {
      "metadata": {
        "description": "Admin user password - must be 16-128 characters, must contain 3 of uppercase, lowercase, numbers and non-alphanumeric characters, and cannot contain all or part of the login name"
      },
      "type": "securestring"
    },
    "subnetId": {
      "metadata": {
        "description": "The subnet id of the subnet to deploy the instance"
      },
      "type": "string"
    },
    "tags": {
      "defaultValue": {},
      "metadata": {
        "description": "Tags for the Managed Instance SQL resource."
      },
      "type": "object"
    }
  },
  "resources": [
    {
      "apiVersion": "2019-06-01-preview",
      "identity": {
        "type": "SystemAssigned"
      },
      "location": "[parameters('location')]",
      "name": "[parameters('sqlManagedInstanceName')]",
      "properties": {
        "administratorLogin": "[parameters('sqlManagedInstanceAdminLogin')]",
        "administratorLoginPassword": "[parameters('sqlManagedInstancePassword')]",
        "collation": "[parameters('sqlManagedInstance-collation')]",
        "hardwareFamily": "[parameters('sqlManagedInstance-hardwareFamily')]",
        "licenseType": "[parameters('sqlManagedInstance-licenseType')]",
        "publicDataEndpointEnabled": "false",
        "storageSizeInGB": "[parameters('sqlManagedInstance-storageSizeInGB')]",
        "subnetId": "[parameters('subnetId')]",
        "vCores": "[parameters('sqlManagedInstance-vCores')]"
      },
      "sku": {
        "name": "[parameters('sqlManagedInstance-skuName')]",
        "tier": "[parameters('sqlManagedInstance-skuEdition')]"
      },
      "tags": "[parameters('tags')]",
      "type": "Microsoft.Sql/managedInstances"
    }
  ],
  "variables": {}
}
```

{{</ disclose >}}

This template is long, but I wanted to include the full template as it
took me a while to work out all the details and I hope it helps someone
else.  I exposed any properties that I could imagine changing in the
future as parameters.

### Tie it all together

```terraform
resource "azurerm_template_deployment" "sqlmi" {
  name                = "${var.location}-sqlmi-${var.environment}"
  resource_group_name = azurerm_resource_group.deployment.name
  deployment_mode     = "Incremental"
  template_body       = file("deploy.json")

  parameters_body = jsonencode({
    subnetId                           = { value = data.terraform_remote_state.common.outputs.subnets["sqlmi"].id }
    sqlManagedInstanceName             = { value = var.instance_name == null ? "${var.location}-sqlmanagedinstance-${var.environment}-1" : var.instance_name }
    sqlManagedInstanceAdminLogin       = { value = var.dbadmin_user }
    sqlManagedInstancePassword         = { value = local.dbadmin_password }
    sqlManagedInstance-vCores          = { value = var.instance_vcores }
    sqlManagedInstance-storageSizeInGB = { value = var.instance_storage }
    tags = { value = merge(local.tags, {
      Name = "${var.location}-sqlmi-${var.environment}"
      Type = "SQL Managed Instance"
    }) }
  })
  timeouts { # in testing, took about 4 hours
    create = "6h"
    update = "6h"
    delete = "6h"
  }
}
```

Here, I've left the tags in my example as it shows how one can use
`parameters_body` to pass complex objects that are not supported by the
`parameters` attribute.  This pattern couples the template's parameters
with terraform variables, which themselves can be computed from other
variables.  Any parameters not supplied will use the default from
`deploy.json`.

### Runtime

It takes a *long* time to create a manages SQL instance.  Microsoft
says it may take up to 24 hours.  In testing, I've observed it taking
about 4 hours to create and 7 hours to destroy.  Terraform Cloud limits
run times to two hours, so during testing I switched the workspace to
local execution for the initial apply which creates the deployment, and
switched back to remote execution afterwards.  Once I had it working,
I opened a ticket with Hashicorp and asked them to change the default
timeout for our tenant.

## Updating the template

The main disadvantage to this design is that terraform is managing the
deployment, *not* the individual resources created by the deployment.
That said, it is possible to use terraform to update the managed
instance *in-place* by updating the template (or just its parameters).

### Adding an output

As mentioned at the top, I wanted to have terraform output the resource
identifier of the managed instance so that another workspace could use
this to do some logging and data collection.  Unfortunately, my original
template didn't expose this output, so I added it.

```diff
diff --git a/deploy.json b/deploy.json
index d13d8ec..0e15532 100644
--- a/deploy.json
+++ b/deploy.json
@@ -5,6 +5,10 @@
     "fqdn": {
       "type": "string",
       "value": "[reference(parameters('sqlManagedInstanceName')).fullyQualifiedDomainName]"
+    },
+    "id": {
+      "type": "string",
+      "value": "[resourceId('Microsoft.Sql/managedInstances', parameters('sqlManagedInstanceName'))]"
     }
   },
   "parameters": {
```

Then, I could expose the output from the `azurerm_template_deployment`
as a terraform output:

```diff
diff --git a/outputs.tf b/outputs.tf
index 35b46f4..6614bf2 100644
--- a/outputs.tf
+++ b/outputs.tf
@@ -3,6 +3,11 @@ output "instance_fqdn" {
   value       = azurerm_template_deployment.sqlmi.outputs["fqdn"]
 }

+output "instance_id" {
+  description = "Resource Id of Azure SQL Managed Instance"
+  value       = azurerm_template_deployment.sqlmi.outputs["id"]
+}
+
 output "dbadmin_user" {
   description = "Database admin username"
   value       = var.dbadmin_user
```

### Sequencing

Each of the above changes must be applied in sequence because the
`azurerm_template_deployment` does not have the output value in its
state until it is redeployed.  Performing a terraform apply will update
the template in place and redeploy.  Since it is redeployed in the same
context, it will not destroy/re-create any resources.

I was very excited to see that this worked the way I hoped and expected.
I also did a bit of research beforehand and tested with a sandbox
account to confirm.  Despite this, even though I was working in our dev
environment, I created a "Delete" lock on the whole resource group, just
to be safe.

### Potential issues

It wasn't necessarily this simple in practice, as the database
administrator had manually modified the resource since the initial
deployment.  Because terraform isn't managing the resource (only the
deployment template), it can't resolve any discrepancies.  When I did
the first apply, I received an error:

```json
{
  "status": "Failed",
  "error": {
    "code": "ResourceDeploymentFailure",
    "message": "The resource operation completed with terminal provisioning state 'Failed'.",
    "details": [
      {
        "code": "ManagedInstanceInvalidStorageSizeLessThenCurrentSizeUsed",
        "message": "Invalid storage size: Storage size limit (256 GB) is less that current storage used (296 GB). Please specify higher storage size limit."
      }
    ]
  }
}
```

This is one of the drawbacks of this design.  Fortunately, I was
able to just look at what it was currently set to and update the
`instance_storage` workspace variable to match.

Additionally, after the deployment failure, terraform got confused.
After the variable was updated, a prospective plan showed:

```text
Error: Invalid index

  on outputs.tf line 3, in output "instance_fqdn":
   3:   value       = azurerm_template_deployment.sqlmi.outputs["fqdn"]
    |----------------
    | azurerm_template_deployment.sqlmi.outputs is empty map of string

The given key does not identify an element in this collection value.
```

This, I believe, is because terraform is updating its state from
the now-failed deployment, which does not have any outputs.  Fortunately,
deleting a deployment does not affect any of the resources it created.
The portal even confirms this for you:

![Deleting a deployment](delete-deployment.png#center)

Afterwards, a terraform apply will create the deployment cleanly without
destroying/re-creating the resources created by the deployment.  This
is very nice, and a useful escape hatch when things go awry.

## Future

Eventually, the Azure provider will have a native resource type for
the SQL managed instance.  Once it appears feature complete and stable,
I will investigate migrating the infrastructure to have Terraform manage
those resources.  I'm expecting that I should just be able to `import`
the existing resources.

While writing this blog, I noticed the following note in the [documentation][azurerm_template_deployment-docs]:

[azurerm_template_deployment-docs]: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/template_deployment

{{< blockquote >}}
The `azurerm_template_deployment` resource has been superseded by the
`azurerm_resource_group_template_deployment` resource. The existing
`azurerm_template_deployment` resource will be deprecated (but still
available) in version 3.0 of the AzureRM Terraform Provider - we
recommend using the `azurerm_resource_group_template_deployment`
resource for new deployments.
{{</ blockquote >}}

I will investigate the motivation and reasoning behind this and consider
migrating to this resource in the interim.
