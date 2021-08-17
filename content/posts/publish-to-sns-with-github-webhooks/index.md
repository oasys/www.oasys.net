---
title: "Publish to SNS with GitHub webhooks"
date: 2021-08-16
tags:
  - github
  - aws
  - sns
  - terraform
  - rancid
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Using a Lambda integration to verify GitHub webhook signatures and publish to an SNS topic
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "lambda-integration-cover.png"
    alt: "Process flow of a webhook through API Gateway using a lambda integration to publish to SNS "
    relative: true

---


## Motivation and Design

I have a bunch of "audit scripts" that run against the network
configurations (and other data sources, such as DNS and DHCP) to check
for common problems, mistakes, and inconsistencies.  They run on a
centralized server that periodically fetches the latest data from all
these sources, runs the scripts, and emails about any discrepancies.
This data sources are kept in git repositories, either updated by
operations staff, or automatically.  In the case of networking gear,
by a tool called [RANCID][rancid] that collects the text configuration
and output of many useful "show" commands and pushes any changes a git
repository for the role/group of the device.

[rancid]: https://shrubbery.net/rancid/

In modernizing our stack to a more event-driven approach, I wanted
to re-architect a bit so that any commit to these repositories would
trigger a run of the appropriate audit scripts.  Since each check is
relatively independent, this seemed like a good use of [Amazon Simple
Notification Service][sns] (SNS).  I could configure a webhook to
publish to an SNS topic whenever there was an update pushed to a GitHub
repository.

{{< figure src="direct.png" align="center"
    title="Direct Webhook to SNS"
    caption="THIS WILL NOT WORK" >}}

I expected this to be a simple configuration, but it wasn't all that
straightforward.  For what I think would be such a common task, it
took me quite a bit of research and reading of documentation to get a
satisfactory solution.  Here I detail the approach(es) that I've come up
with to help assist anyone else that needs this functionality.

I will share two workable solutions.  A [simple
one](#api-gateway-service-proxy) without authentication, and a [more
complex one](#api-gateway-lambda-integration) that allows you to specify
a "secret" token with the GitHub webhook.

[sns]: https://docs.aws.amazon.com/sns/index.html

## Alternatives

### GitHub Services

There is a lot old information out there, including this AWS [blog
post][dynamic-github-actions], that recommends using "GitHub
Services" to integrate with AWS services such as SNS.  This
feature has been [deprecated][deprecate-github-services] and they
[recommend][replace-github-services] using webhooks instead.

[dynamic-github-actions]: https://aws.amazon.com/blogs/compute/dynamic-github-actions-with-aws-lambda/
[deprecate-github-services]: https://developer.github.com/changes/2018-04-25-github-services-deprecation/
[replace-github-services]: https://docs.github.com/en/developers/overview/replacing-github-services

### GitHub Actions

Another approach would be to use [GitHub Actions][actions] to publish
to SNS.  Here is an example [action][github-action-publish-sns] which
allows you to do this with just a few lines in a workflow file.  This
may be a simpler solution for some, but I did not choose -- or test --
this path, as I did not want to modify the repositories themselves and
wanted to manage this entirely within Terraform.

[actions]: https://github.com/features/actions
[github-action-publis-sns]: https://github.com/marketplace/actions/aws-sns-publish-topic

## API Gateway Service Proxy

This is the simplest solution I've found: using [API
Gateway][api-gateway] and a service proxy to build a HTTP REST API with a
resource that will publish to an SNS topic.  The integration allows for
manipulation of the input data into the format needed by the SNS API by
using the flexible [Velocity Templating Language (VTL)][vtl].  There
is no additional coding needed.

The biggest drawback of this solution is that there is no authorization
on the endpoint; anyone can POST to this URL.  If you have other
means of limiting access, such as limiting IP access with a [resource
policy][resource-policy], or using a [VPC endpoint][interface-endpoint]
for the REST API with an [endpoint policy][endpoint-policy],
then this may be your best bet.  Later, I explore [another
solution](#api-gateway-lambda-integration) that works with the native
signature authorization available with GitHub webhooks.

[api-gateway]: https://aws.amazon.com/api-gateway/
[vtl]: http://velocity.apache.org/engine/devel/vtl-reference.html
[resource-policy]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-resource-policies.html
[interface-endpoint]: https://docs.aws.amazon.com/vpc/latest/privatelink/endpoint-services-overview.html
[endpoint-policy]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-vpc-endpoint-policies.html

{{< figure src="service-proxy.png" align="center"
    title="API Gateway Service Proxy to SNS" >}}

### SNS

First, create a topic that we will publish to.

```terraform
resource "aws_sns_topic" "this" {
  name = "sns-topic-${var.environment}-demo"
}
```

For testing, manually create (and confirm) an email subscription to this topic.

### IAM

Next, we need a IAM role that will permit API Gateway to publish to the topic.

```terraform
data "aws_iam_policy_document" "sns-publish" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this.arn]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "apigw-proxy-sns" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "sns-publish" {
  name               = "sns-publish"
  assume_role_policy = data.aws_iam_policy_document.apigw-proxy-sns.json
  inline_policy {
    name   = "sns-publish"
    policy = data.aws_iam_policy_document.sns-publish.json
  }
}
```

### API Gateway

#### API Gateway resource and method

Configure a REST API with a single resource, `/ingest`, which has a
`POST` method configured for the integration with SNS.

I found that the response (and the `response_integration`) _also_ need
to be configured or the integration will not work.

```terraform
resource "aws_api_gateway_rest_api" "sns-proxy" {
  name = "sns-proxy"
}

resource "aws_api_gateway_resource" "sns-ingest" {
  rest_api_id = aws_api_gateway_rest_api.sns-proxy.id
  parent_id   = aws_api_gateway_rest_api.sns-proxy.root_resource_id
  path_part   = "ingest"
}

resource "aws_api_gateway_method" "sns-ingest" {
  rest_api_id   = aws_api_gateway_rest_api.sns-proxy.id
  resource_id   = aws_api_gateway_resource.sns-ingest.id
  authorization = "NONE"
  http_method   = "POST"
}

resource "aws_api_gateway_method_response" "sns-ingest" {
  http_method     = aws_api_gateway_method.sns-ingest.http_method
  resource_id     = aws_api_gateway_resource.sns-ingest.id
  rest_api_id     = aws_api_gateway_rest_api.sns-proxy.id
  status_code     = "200"
  response_models = { "application/json" = "Empty" }
}
```

{{< figure src="service-proxy-console.png" align="center"
    title="Service Proxy definition in AWS Console" >}}

#### API Gateway service proxy configuration

SNS expects to receive the publish request as a POST with all parameters
passed as url-encoded form data in the body of the request.  The [API
Documentation][sns-publish-api] lists both the required (`Message` and
`Topic/TargetArn`) and optional parameters.  Using a request template
allows us to map the data to the format expected by SNS.  I found that
using the AWS CLI in debug mode was a helpful way to see what was
actually being sent to the SNS API.

The `credentials` parameter reference the IAM role we defined earlier to
permit API Gateway to publish to the the topic.

Setting `passthrough_behavior` to `NEVER` rejects any requests that do
not match a request template (`application/json`).

[sns-publish-api]: https://docs.aws.amazon.com/sns/latest/api/API_Publish.html

```terraform
resource "aws_api_gateway_integration" "sns-publish" {
  http_method             = aws_api_gateway_method.sns-ingest.http_method
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_resource.sns-ingest.id
  rest_api_id             = aws_api_gateway_rest_api.sns-proxy.id
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:sns:path//"
  credentials             = aws_iam_role.sns-publish.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  request_templates = {
    "application/json" = join("&", [
      "Action=Publish&TopicArn=$util.urlEncode('${aws_sns_topic.this.arn}')",
      "Message=$util.urlEncode($input.body)",
      "Subject=$util.urlEncode('webhook')"
    ])
  }
  passthrough_behavior = "NEVER"
}

resource "aws_api_gateway_integration_response" "sns-publish" {
  resource_id        = aws_api_gateway_resource.sns-ingest.id
  rest_api_id        = aws_api_gateway_rest_api.sns-proxy.id
  http_method        = aws_api_gateway_method.sns-ingest.http_method
  status_code        = "200"
  response_templates = {
    "application/json" = jsonencode({ body = "Message received." })
  }
}
```

#### API Gateway deployment and stage

A deployment and stage need to be created to deploy the REST API.  I
copied the trigger from the terraform documentation; note the caveats on
types of changes that might not trigger a redeployment.

```terraform
resource "aws_api_gateway_deployment" "sns-proxy" {
  rest_api_id = aws_api_gateway_rest_api.sns-proxy.id
  # will re-deploy when resource id changes (not all configuration changes)
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.sns-ingest.id,
      aws_api_gateway_method.sns-ingest.id,
      aws_api_gateway_integration.sns-publish.id,
      aws_api_gateway_method_response.sns-ingest.id,
      aws_api_gateway_integration_response.sns-publish.id,
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "sns-proxy" {
  deployment_id = aws_api_gateway_deployment.sns-proxy.id
  rest_api_id   = aws_api_gateway_rest_api.sns-proxy.id
  stage_name    = var.environment
}
```

### GitHub Webhook

Lastly, we configure the webhook on a GitHub repository, specifying the
URL and the content-type.

```terraform
data "github_repository" "repo" {
  full_name = "exampleorg/reponame"
}

resource "github_repository_webhook" "webhook" {
  repository = data.github_repository.repo.name
  events     = ["push"]
  configuration {
    url = "https://${aws_api_gateway_rest_api.sns-proxy.id}.execute-api.${var.region}.amazonaws.com/${var.environment}${aws_api_gateway_resource.sns-ingest.path}"
    content_type = "json"
  }
}
```

## API Gateway Lambda Integration

Once I had the basics working, I went to add authentication.  I had
hoped to use an [API Gateway Lambda authorizer][authorizer] to
validate the signature GitHub generates against the webhook payload.
This shared secret would allow me to restrict access to the API to only
valid senders, but writing a small lambda function to validate the
signature in the request header.

[authorizer]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html

{{< figure src="service-proxy-with-authorizer.png" align="center"
    title="API Gateway Service Proxy to SNS with Authorizer"
    caption="THIS WILL NOT WORK" >}}

Unfortunately, this is not possible.  As far as I can tell, authorizers
do not have access to the request payload.   Since validating the signature
requires running the same hash algorithm on the received payload and comparing
the received and calculated digests, a lambda authorizer is not the tool
for the job.

Instead, I removed the SNS proxy and replaced it with a lambda
integration which first verifies the signature and then publishes to the
SNS topic.

{{< figure src="lambda-integration.png" align="center"
    title="API Gateway with Lambda Integration" >}}

There's some significant overlap, and some subtle differences, between
this solution and the previous "no-authorization" solution.  For the
sake of clarity, I will include all the relevant code for this solution,
despite the repetition.

### SNS

As before, create a topic.

```terraform
resource "aws_sns_topic" "topic" {
  name = "sns-topic-${var.environment}-demo"
}
```

### IAM

Define an IAM role that will be assumed by the lambda function,
permitting it to publish to the topic.

```terraform
data "aws_iam_policy_document" "sns-publish" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.topic.arn]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "apigw-proxy-lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "assume-lambda" {
  name               = "assume-lambda"
  assume_role_policy = data.aws_iam_policy_document.apigw-proxy-lambda.json
  inline_policy {
    name   = "sns-publish"
    policy = data.aws_iam_policy_document.sns-publish.json
  }
}
```

### API Gateway

#### API Gateway integration

This part is a bit simpler than before.  Define a single `/ingest`
resource, and map its `POST` method to invoke the (to-be-defined) lambda
function.  In this case no response configuration is needed.

```terraform
resource "aws_api_gateway_rest_api" "sns-proxy" {
  name = "sns-proxy"
}

resource "aws_api_gateway_resource" "sns-ingest" {
  rest_api_id = aws_api_gateway_rest_api.sns-proxy.id
  parent_id   = aws_api_gateway_rest_api.sns-proxy.root_resource_id
  path_part   = "ingest"
}

resource "aws_api_gateway_method" "sns-ingest" {
  rest_api_id   = aws_api_gateway_rest_api.sns-proxy.id
  resource_id   = aws_api_gateway_resource.sns-ingest.id
  authorization = "NONE"
  http_method   = "POST"
}

resource "aws_api_gateway_integration" "sns-publish" {
  rest_api_id             = aws_api_gateway_rest_api.sns-proxy.id
  resource_id             = aws_api_gateway_resource.sns-ingest.id
  http_method             = aws_api_gateway_method.sns-ingest.hrtp_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}
```

{{< figure src="lambda-integration-console.png" align="center"
    title="Lambda Proxy definition in AWS Console" >}}

#### API Gateway deployment and stage

Same as before -- except a couple fewer resources on the trigger --
define a deployment and stage for the REST API.

```terraform
resource "aws_api_gateway_deployment" "sns-proxy" {
  rest_api_id = aws_api_gateway_rest_api.sns-proxy.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.sns-ingest.id,
      aws_api_gateway_method.sns-ingest.id,
      aws_api_gateway_integration.sns-publish.id,
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "sns-proxy" {
  deployment_id = aws_api_gateway_deployment.sns-proxy.id
  rest_api_id   = aws_api_gateway_rest_api.sns-proxy.id
  stage_name    = var.environment
}
```

### Lambda

Upload the code, passing the ARN of the SNS topic and the webhook secret
to the function as environment variables.  Use the IAM role defined earlier
as the function's execution role, so that it has permissions to publish
to the SNS topic.

Give API Gateway permission to run the function, by
specifying the principal and `source_arn`.  The [API Gateway
Documentation][apig-permissions] was helpful in determining its ARN.

[apig-permissions]: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html

```terraform
data "aws_caller_identity" "current" {}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.sns-proxy.id}/*/${aws_api_gateway_method.sns-ingest.http_method}${aws_api_gateway_resource.sns-ingest.path}"
}

data "archive_file" "lambda" {
  type        = "zip"
  output_path = "lambda.zip"
  source_file = "lambda.py"
}

resource "random_password" "github-secret" {
  length = 32
}

resource "aws_lambda_function" "lambda" {
  filename      = "lambda.zip"
  function_name = "webhook-sns-publish"
  handler       = "lambda.handler"
  runtime       = "python3.8"
  role          = aws_iam_role.assume-lambda.arn
  environment {
    variables = {
      "GITHUB_SECRET" = random_password.github-secret.result
      "TOPIC_ARN"     = aws_sns_topic.topic.arn
    }
  }
  source_code_hash = data.archive_file.lambda.output_base64sha256
}
```

### Lambda Function

This is a minimal to check the signature and, if valid, publish the
payload to the SNS topic.

According to their [developer documentation][github-webhook-signature],
GitHub generates a signature by "using a HMAC hex digest to compute the
hash" using the secret token and the payload of the webhook it is sending.
This hash is sent in the `X-Hub-Signature-256` header.  To validate it,
we do the same computation with the secret token and the received payload
and check to see if the resulting hash is the same.

Publishing to the topic uses the boto3 library to submit the necessary
parameters to the SNS API.

[github-webhook-signature]: https://docs.github.com/en/developers/webhooks-and-events/webhooks/securing-your-webhooks

```python
import os
import boto3
import botocore
from json import dumps
from hashlib import sha256
from hmac import HMAC, compare_digest


def handler(event, context):
    if verify_signature(event["headers"], event["body"]):
        if publish_sns(event["body"]):
            return respond("Success")
        else:
            return respond("Failed", 500)
    return respond("Forbidden", 403)


def respond(message, code=200):
    return {"statusCode": code, "body": dumps({"message": message})}


def publish_sns(message):
    try:
        arn = os.environ.get("TOPIC_ARN")
        client = boto3.client("sns")
        response = client.publish(
            TargetArn=arn,
            Message=dumps({"default": dumps(message)}),
            MessageStructure="json",
        )
    except botocore.exceptions.ClientError as e:
        print(f"ClientError: {e}")
        return False
    else:
        return True


def verify_signature(headers, body):
    try:
        secret = os.environ.get("GITHUB_SECRET").encode("utf-8")
        received = headers["X-Hub-Signature-256"].split("sha256=")[-1].strip()
        expected = HMAC(secret, body.encode("utf-8"), sha256).hexdigest()
    except (KeyError, TypeError):
        return False
    else:
        return compare_digest(received, expected)
```

### GitHub Webhook

Finally, manage a webhook on the specified GitHub repository, setting
the `url` to the API endpoint and supplying the shared key as `secret`.

```terraform
data "github_repository" "repo" {
  full_name = "exampleorg/reponame"
}

resource "github_repository_webhook" "webhook" {
  repository = data.github_repository.repo.name
  events     = ["push"]
  configuration {
    url          = "https://${aws_api_gateway_rest_api.sns-proxy.id}.execute-api.${var.region}.amazonaws.com/${var.environment}${aws_api_gateway_resource.sns-ingest.path}"
    secret       = random_password.github-secret.result
    content_type = "json"
  }
}
```

## Conclusion

The whole time I was building and testing this, I kept thinking to
myself, "I must be overlooking a more obvious solution."  I've asked
around, and it seems that others have also run into this issue, but
ended up using a different approach that didn't involve authorization.
If you know of a better/different solution, please reach out!

I plan to flesh this out and create a terraform module out of it, as I
expect I will want to use this pattern in other places.
