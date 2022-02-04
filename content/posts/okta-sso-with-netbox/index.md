---
title: "Integrating Okta SSO with NetBox"
date: 2022-02-03
tags:
  - netbox
  - sso
  - okta
  - terraform
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Instructions for configuring NetBox and Okta for native SSO authentication.
  Both Terraform and manual steps are provided.
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "cover.png"
    alt: "Okta and NetBox logos"
    relative: true

---

## Overview

[NetBox][netbox] is a [DCIM][DCIM] and [IPAM][IPAM] tool for modeling
infrastructure and serving as a source of truth for the desired state
of the network.  [Okta][okta] is an [IAM][IAM] company that offers a
[single sign-on][okta-sso] product, which can act as a central point to
manage user access.

As of NetBox version [3.1.0][v3.1.0], native support
for SSO authentication was added via inclusion of
[python-social-auth][social-auth].  This library supports [many
backends][backends], including Okta via both [OAuth2][oath2] and
[OpenId Connect][openid].  Until then, the only options for an external
authentication provider were [LDAP][LDAP], an external [plugin][plugin], or
moving the authentication to a proxy and passing the results to netbox via
[HTTP headers][header-auth].

This is how I set up NetBox to authenticate with Okta via native SSO integration.

[netbox]: https://netbox.readthedocs.io/en/stable/
[DCIM]: https://en.wikipedia.org/wiki/DCIM
[IPAM]: https://en.wikipedia.org/wiki/IP_address_management
[okta]: https://www.okta.com
[okta-sso]: https://www.okta.com/products/single-sign-on/
[IAM]: https://en.wikipedia.org/wiki/IAM
[v3.1.0]: https://github.com/netbox-community/netbox/releases/tag/v3.1.0
[netbox-sso]: https://netbox.readthedocs.io/en/stable/administration/authentication/#single-sign-on-sso
[social-auth]: https://github.com/python-social-auth
[backends]: https://python-social-auth.readthedocs.io/en/latest/backends/index.html
[oauth2]: https://oauth.net/2/
[openid]: https://openid.net/connect/
[LDAP]: https://netbox.readthedocs.io/en/stable/installation/6-ldap/
[plugin]: https://github.com/jeremyschulman/netbox-plugin-auth-saml2
[header-auth]: https://netbox.readthedocs.io/en/stable/administration/authentication/#http-header-authentication

## Requirements

- NetBox 3.1.7 or greater
- An Okta account

Despite NetBox adding single sign-on support in v3.1.0, there was
a [bug][social-auth-bug] in python-social-auth] that
prevented it from working with Okta.  This is now fixed upstream, and
NetBox requirements.txt is updated to this new version.

If you are not yet an Okta customer, or if you don't have administrative
access to your organization's tenant, Okta offers fully-functional
free developer accounts at [developer.okta.com][okta-dev] for testing
integrations with their product.

[social-auth-bug]: https://github.com/python-social-auth/social-core/pull/588
[okta-dev]: https://developer.okta.com

## Okta

Configure a NetBox application in Okta.  Here is an example minimal
[terraform][terraform] configuration as well as steps and screenshots of
the manual process using the Okta administrative web interface.  Choose
one.

[terraform]: https://registry.terraform.io/providers/okta/okta/latest/docs

### Terraform

```terraform
variable "hostname" { default = "netbox.example.com" }

resource "okta_app_oauth" "netbox" {
  label                     = "NetBox"
  type                      = "web"
  grant_types               = ["authorization_code", "client_credentials", "implicit"]
  response_types            = ["code", "token", "id_token"]
  hide_web                  = false
  login_mode                = "SPEC"
  login_uri                 = "https://${var.hostname}/oauth/login/okta-openidconnect/"
  redirect_uris             = ["https://${var.hostname}/oauth/complete/okta-openidconnect/"]
  post_logout_redirect_uris = ["http://${var.hostname}/disconnect/okta-openidconnect/"]
}

data "okta_group" "everyone" { name = "Everyone" }

resource "okta_app_group_assignment" "access" {
  app_id   = okta_app_oauth.netbox.id
  group_id = data.okta_group.everyone.id
}

output "netbox_configuration" {
  sensitive = true
  value     = <<-EOM
  REMOTE_AUTH_BACKEND                    = 'social_core.backends.okta_openidconnect.OktaOpenIdConnect'
  SOCIAL_AUTH_OKTA_OPENIDCONNECT_KEY     = '${okta_app_oauth.netbox.client_id}'
  SOCIAL_AUTH_OKTA_OPENIDCONNECT_SECRET  = '${okta_app_oauth.netbox.client_secret}'
  SOCIAL_AUTH_OKTA_OPENIDCONNECT_API_URL = 'https://${var.hostname}/oauth2/'
  EOM
}
```

### Manual

In the Okta admin portal, create a new "App Integration".  Choose OpenID
Connect as the Sign-in method, and set the application type to "Web
Application".

{{< figure src="create-new-app.png" align="center"
    title="Create App Integration" >}}

Under General Settings, set the app name, NetBox, and optionally
upload a [logo].  Set the Sign-in and Sign-out redirect URIs to
`https://netbox.example.com/oauth/complete/okta-openidconnect`
and `http://netbox.example.com/disconnect/okta-openidconnect/`,
respectively.  Save.

{{< figure src="new-app-settings.png" align="center"
    title="Create New App Settings" >}}

If you'd like to also be able to initiate user login
from the Okta dashboard, also select "Implicit (hybrid)"
grant type, check off the applicable options under
"Application Visibility", and set "Initiate login URI" to
`https://netbox.example.com/oauth/login/okta-openidconnect/`.

{{< figure src="application-settings.png" align="center" >}}
{{< figure src="login-settings.png" align="center" >}}

Note the "Client ID", "Client secret", and "Okta domain".  These will
be used in configuring NetBox.  There is a handy "copy to clipboard"
button to the right of each field.

{{< figure src="client-credentials.png" align="center"
    title="Client Credentials and Okta Domain"
    caption="collect info for entering into netbox configuration" >}}

## Netbox Configuration

### `requirements.txt`

Install the `python-jose` dependency, and add it to local_requirements to
persist this across upgrades.

```bash
root@d-netbox-a:/opt/netbox# . venv/bin/activate
(venv) root@d-netbox-a:/opt/netbox# pip install python-jose
(venv) root@d-netbox-a:/opt/netbox# echo python-jose >> local_requirements.txt
```

### `configuration.py`

In `configuration.py`, set the following:

```python
REMOTE_AUTH_BACKEND = 'social_core.backends.okta_openidconnect.OktaOpenIdConnect'
SOCIAL_AUTH_OKTA_OPENIDCONNECT_KEY= 'CLIENT_ID'
SOCIAL_AUTH_OKTA_OPENIDCONNECT_SECRET= 'CLIENT_SECRET'
SOCIAL_AUTH_OKTA_OPENIDCONNECT_API_URL= 'https://OKTA_DOMAIN/oauth2/'
SOCIAL_AUTH_PIPELINE = [
    "social_core.pipeline.social_auth.social_details",
    "social_core.pipeline.social_auth.social_uid",
    "social_core.pipeline.social_auth.auth_allowed",
    "social_core.pipeline.social_auth.social_user",
    "social_core.pipeline.social_auth.associate_by_email",
    "social_core.pipeline.user.create_user",
    "social_core.pipeline.social_auth.associate_user",
    "social_core.pipeline.social_auth.load_extra_data",
    "social_core.pipeline.user.user_details"
]
REMOTE_AUTH_HEADER = 'HTTP_REMOTE_USER'
REMOTE_AUTH_AUTO_CREATE_USER = True
```

Change the `CLIENT_ID` and `CLIENT_SECRET` above to the "Client ID" and "Client
secret" fields from the Okta admin interface.  Also change the `OKTA_DOMAIN` to
your custom domain or the "Okta domain" listed on the Okta app page.

The [pipeline documentation][pipeline] was very helpful in determining
the what would work in my environment.  Specifically in my case, since
I was migrating an installation using LDAP authentication, I wanted new
logins to map to existing users if the email address matched, otherwise
create a new user.  If you have different needs, this is a good place to
look for an answer.

[pipeline]: https://python-social-auth.readthedocs.io/en/latest/pipeline.html

## Test

Restart NetBox and go to the login page.  Click on the `okta-openidconnect` link
to login via SSO.  You can still use the username/password fields for any
local accounts.

{{< figure src="netbox-login.png" align="center"
    title="NetBox login page" >}}

If you set it up, your Okta users can also use the Okta End-User Dashboard to
log into the NetBox instance.

{{< figure src="okta-dashboard-login.png" align="center"
    title="NetBox login on Okta Dashboard" >}}
