---
title: "Migrating a Perl CGI to AWS Lambda"
date: 2021-08-30
tags:
  - perl
  - aws
  - lambda
  - s3
  - rancid
  - textfsm
  - genie
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Using a custom runtime and event-driven static site generation
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "cover.png"
    alt: "Lambda and Perl Camel"
    relative: true

---

## Motivation

In migrating our NOC website to from a traditional Apache server
to a serverless architecture, I've needed to update or replace any
dynamic components.  For example, replacing a [Wordpress][wordpress]
installation with [Hugo][hugo] to publish static content to a S3 bucket
served by [CloudFront][cloudfront].  In this particular case, it was
a CGI script that reads our firewall configurations and presents a
web page for visualizing and searching the many object-groups and
access-lists.  I chose to migrate this to run as a [Lambda][lambda].

What makes this notable, is this CGI script was written in Perl.  Perl
is **not** one of the AWS Lambda's natively supported languages, Java
Go, PowerShell, Node.js, C#, Python, and Ruby (at the time of this
writing).  The perl community has done some work already to leverage
the Lambda Runtime API to run perl, which I've used here.

[wordpress]: https://wordpress.org
[hugo]: https://gohugo.io
[cloudfront]: https://aws.amazon.com/cloudfront/
[lambda]: https://aws.amazon.com/lambda/

## Why Perl

Why not just rewrite the script in a different language?  I considered
this first, but due to the complexity of the script, I thought that
adding a simple handler function to wrap the script would be a much
more expedient and less-risky change.  Once the migration was complete,
I could write a workalike replacement in, say, python, and drop it in
without impacting the rest of the system.

I originally wrote this tool in 2005 (over 16 years ago!) and it has had
numerous updates and changes since then to meet evolving needs as well as
to add new features (such as IPv6 support).  It relies on parsing the
firewall text configuration file into a data structure, and to do this
-- according to a few `grep`'s I did -- has 100+ `if`/`elsif` statements
and almost as many regular expressions.  Some of those are complex
multi-line regexes, as this sample code snippet shows:

```perl
[...]
} elsif (/^(?:ipv6 )?access-list (\S+)(?: extended)? (deny|permit) (object-group \S+|\S+) (.*)$/) {
  my $int = 'acl';
  my ($name, $action, $proto, $ace) = ($1, $2, $3, $4);
  if ($ace =~ /(any[46]?|host\ \S+|object-group\ \S+|$ipmaskre)\ # src
               ()                                                # sport
               (any[46]?|host\ \S+|object-group\ \S+|$ipmaskre)  # dst
               (?:\ ((?:eq|lt|gt|neq)\ \S+|                      # dport
                     range\ \S+\ \S+|
                     object-group\ \S+|
                     \S+))?
              /x
      or
      $ace =~ /(any[46]?|host\ \S+|object-group\ \S+|$ipmaskre)\ # src
               (?:((?:eq|lt|gt|neq)\ \S+|                        # sport
                   range\ \S+\ \S+|
                   object-group\ \S+)\ )
               (any[46]?|host\ \S+|object-group\ \S+|$ipmaskre)  # dst
               (?:\ ((?:eq|lt|gt|neq)\ \S+|                      # dport
                     range\ \S+\ \S+|
                     object-group\ \S+|
                     \S+))?
              /x) {

    my ($src, $sport, $dst, $dport) = ($1, $2, $3, $4);
    $sport =~ s/^(.+)/port-object \1/ if ($sport !~ /^object-group /);
    $dport =~ s/^(.+)/port-object \1/ if ($dport !~ /^object-group /);
    cidrize($src, $dst);
    push @{$c{$int}{$name}}, [$action,$proto,$src,$sport,$dst,$dport];
[...]
```

It will be a nice project, some time in the future, to rewrite this
with a couple decades more programming experience and evolution of the
available tools.  My current plan is to rewrite it in python using
[TextFSM][textfsm] or [Genie][genie]. I will certainly share here when
I do that.  For now, the script "just works"&trade; and I don't want to
break it.

[textfsm]: https://github.com/google/textfsm
[genie]: https://developer.cisco.com/docs/genie-docs/

## Design

In the current deployment, when the CGI script is called, it reads a
local file with the current configuration of the device in question
(supplied as a query parameter), parses the configuration, and returns
the HTML to the browser.  It is a "single-page app" in the sense that
all the CSS and Javascript are included in the response, to allow the
user to interactively navigate and search the firewall rules.  There is
a small web form which sends a POST back to itself to allow the user to
choose from a list of devices.  The device configurations are on disk,
and kept current by a different process.

{{< figure src="perl-lambda.png" align="center"
    title="Dynamically updating the static content" >}}

In order to replicate this user experience, I leveraged some of my
[previous work][last-post] where I automatically update a private S3
bucket with the device configurations whenever the corresponding GitHub
repository changes.  The post expands on that, taking the data from the
private bucket and automatically generating the static HTML for the
user to access.

In general, a task like this would be a great use for [Object
Lambda][object-lambda], where the response to a S3 GET request is
processed by a custom Lambda function.  In this case, though, the
generated HTML is always the same for a given input file. It doesn't
make sense to re-process the data for every request.  Instead, I
decided to build it so the function is triggered by S3 events -- when
a new file from a push is written to the bucket -- and the resulting
HTML written to a public bucket.  In the real-world deployment this
is an [Okta][okta]-authenticated CloudFront distribution, and this
architecture lends itself well to caching.  For simplicity's sake this
example writes its output to a publicly-available S3 bucket.

[object-lambda]: https://aws.amazon.com/s3/features/object-lambda/
[okta]: https://www.okta.com
[last-post]: {{< relref "/posts/publish-to-sns-with-github-webhooks" >}}

## Public Website

Create a simple S3 public website to serve the generated file(s).  To
prevent unintentional data exposure, AWS has made it the default for
buckets to be private.  The `acl` and `policy` must be explicitly set to
allow public access.

```terraform
data "aws_iam_policy_document" "public-website" {
  statement {
    actions = ["s3:GetObject"]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    resources = ["${aws_s3_bucket.html.arn}/*"]
  }
}

resource "aws_s3_bucket" "html" {
  bucket = "${var.name}-html"
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "public" {
  bucket = aws_s3_bucket.html.id
  policy = data.aws_iam_policy_document.public-website.json
}
```

## Repository Bucket

This is the bucket where the source data is stored.  The mechanism for
keeping this data current isn't included in this post; In a previous
post I documented [one approach][last-post] for automatically populating
this bucket whenever a particular set of GitHub repositories are
updated.

```terraform
resource "aws_s3_bucket" "repos" {
  bucket = "${var.name}-repos"
  acl    = "private"
}
```

## IAM

Create an IAM role that the Lambda function can assume that gives it
access to read from the private repos bucket and write to the public
HTML bucket.

```terraform
data "aws_iam_policy_document" "fwacl" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.repos.arn}/*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.html.arn}/*"]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "assume-lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "fwacl" {
  name               = "assume-lambda-fwacl"
  assume_role_policy = data.aws_iam_policy_document.assume-lambda.json
  inline_policy {
    name   = "fwacl"
    policy = data.aws_iam_policy_document.fwacl.json
  }
}
```

## Lambda Function

The Lambda function uses the [AWS::Lambda][perl-aws-lambda] module.
This works by using the generic AWS Linux 2 runtime and specifying the
`AWS::Lambda` layer.  The script uses some additional Perl modules,
[Paws][paws] and [CGI][cgipm].  `Paws` is provided by another layer,
as referenced in the [AWS::Lambda Documentation][paws-support].  Since
[CGI.pm is no longer in the Perl core][cgipm-core], we also reference a
custom layer (which we will build later) including this module.

Configure the function to use the IAM role create earlier, giving it
permissions to access the necessary buckets.

An environment variable indicating the name of the output bucket is
supplied to the function.  The name of the input bucket and the input
file(s) will be provided in the function payload by the S3 notification,
so they do not need to be defined here.

The `function_name` and `handler` attributes tell `AWS::Lambda` where
to find the handler routing.  With this configuration, it will call the
Perl subroutine named `handler` in the file `fwacl.pl` in the Lambda zip
archive.

[perl-aws-lambda]: https://metacpan.org/pod/AWS::Lambda
[paws]: https://metacpan.org/pod/Paws
[paws-support]: https://metacpan.org/pod/AWS::Lambda#Paws-SUPPORT
[cgipm]: https://metacpan.org/dist/CGI/view/lib/CGI.pod
[cgipm-core]: https://metacpan.org/dist/CGI/view/lib/CGI.pod#CGI.pm-HAS-BEEN-REMOVED-FROM-THE-PERL-CORE

```terraform
data "archive_file" "lambda" {
  type        = "zip"
  output_path = "lambda.zip"
  source_file = "fwacl.pl"
}

resource "aws_lambda_function" "fwacl" {
  filename      = "lambda.zip"
  function_name = "fwacl"
  role          = aws_iam_role.fwacl.arn
  handler       = "fwacl.handler"
  runtime       = "provided.al2"
  layers = [
    "arn:aws:lambda:${var.region}:445285296882:layer:perl-5-34-runtime-al2:2",
    "arn:aws:lambda:${var.region}:445285296882:layer:perl-5-34-paws-al2:2",
    aws_lambda_layer_version.cgipm.arn
  ]
  source_code_hash = data.archive_file.lambda.output_base64sha256
  environment {
    variables = {
      "OUTPUT_BUCKET" = aws_s3_bucket.html.id
    }
  }
}
```

## Custom Layer

Here the custom layer is defined to to provide the Perl `CGI` module.

```terraform
resource "aws_lambda_layer_version" "cgipm" {
  filename   = "layer.zip"
  layer_name = "cgipm"

  compatible_runtimes = ["provided.al2"]
  source_code_hash    = filebase64sha256("layer.zip")
}
```

A bash script is used to build the layer locally so terraform can upload
it to AWS.  Any Perl modules listed in the `PERL_MODULES` variable will
be included in this layer.

```bash
#!/bin/bash
set -euo pipefail

PERL_MODULES="CGI"
DIR=layer
FILE=layer.zip

[ -d "$DIR" ] || mkdir "$DIR"
docker run --rm \
  -v "$(pwd):/var/task" \
  -v "$(pwd)/${DIR}/lib/perl5/site_perl:/opt/lib/perl5/site_perl" \
  shogo82148/p5-aws-lambda:build-5.34.al2 \
  cpanm --notest --no-man-pages "$PERL_MODULES"
cd ${DIR} && zip -9 -r "../${FILE}" .
```

## S3 Notification Trigger

The function is triggered whenever specific objects are written to the
bucket.  In our case, all the device configurations we care about for
this script are in the [Rancid][rancid] `core` group, and are named in
format `<location>-<role>fw-<active|standby>`.  The `filter_prefix` and
`filter_suffix` are combined to match only the needed data by limiting
to files only below the specified directory and ending with `fw-active`.
Also, give S3 permission to execute the function.

[rancid]: https://shrubbery.net/rancid/

```terraform
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fwacl.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.repos.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.repos.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.fwacl.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "rancid/core/configs/"
    filter_suffix       = "fw-active"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}
```

## The Perl Function

Here I show the `handler` subroutine.  `AWS::Lambda` calls it with
two arguments, a payload and a context object.  These are native Perl
data structures decoded from the AWS json payload and constructed from
environment variables, respectively.

The needed modules are included via the `use Paws` and `use CGI`
statements.  The files from these packages are present on the lambda's
disk by nature of the added layers, and can be used normally.

I don't show all the supporting subroutines, as they already existed
in the original Perl script.  This handler routine is essentially a
wrapper around what was already there, looping over the provided records
(objects in the bucket that have changed), reading the data from S3
(`GetObject`), processing the data, and writing the output back to the
HTML bucket (`PutObject`).  Note that the `ContentType` attribute must
be set so that S3 can provide the correct [mime-type][mime-type] to the
browser.

For input, it retrieves the needed information from the `$payload` object
to determine the object key and bucket name to process.  For this task
only the source bucket and filename (object key) are needed, but see
the sample payload for the other information that is available about
the event and the object.

{{< disclose open=false summary="Sample payload for s3 event" >}}

```json
{
  "Records": [
    {
      "eventVersion": "2.0",
      "eventSource": "aws:s3",
      "awsRegion": "us-east-1",
      "eventTime": "1970-01-01T00:00:00.000Z",
      "eventName": "ObjectCreated:Put",
      "userIdentity": {
        "principalId": "EXAMPLE"
      },
      "requestParameters": {
        "sourceIPAddress": "127.0.0.1"
      },
      "responseElements": {
        "x-amz-request-id": "EXAMPLE123456789",
        "x-amz-id-2": "EXAMPLE123/5678abcdefghijkl/mnopqrstuvwxyzABCDEFGH"
      },
      "s3": {
        "s3SchemaVersion": "1.0",
        "configurationId": "testConfigRule",
        "bucket": {
          "name": "example-bucket",
          "ownerIdentity": {
            "principalId": "EXAMPLE"
          },
          "arn": "arn:aws:s3:::example-bucket"
        },
        "object": {
          "key": "test/key",
          "size": 1024,
          "eTag": "0123456789abcdef0123456789abcdef",
          "sequencer": "0A1B2C3D4E5F678901"
        }
      }
    }
  ]
}
```

{{< /disclose >}}

If the script exits with an error, `AWS::Lambda` will provide the text
of the error in the "errorMessage" field of the output.  Otherwise, it
will serialize the handler routine's output and return a json string
to Lambda.  For troubleshooting and logging purposes, it is helpful to
populate some data about what was processed.

[mime-type]: https://www.iana.org/assignments/media-types/media-types.xhtml

```perl
use strict;
use POSIX;
use Paws;
use CGI qw/:standard *table/;

my $DEV;
my @DEVS=get_devices();

sub handler {
  my ($payload, $context) = @_;
  my $s3 = Paws->service('S3', region=>$ENV{'AWS_REGION'});
  my $output->{'output_bucket'} = my $output_bucket = $ENV{'OUTPUT_BUCKET'};

  for my $record (@{$payload->{'Records'}}) {
    # get request info
    my $bucket = $record->{'s3'}->{'bucket'}->{'name'};
    my $key = $record->{'s3'}->{'object'}->{'key'};

    ($DEV = $key) =~ s|.*/(.*)-active$|\1|;
    die "Invalid device $DEV" unless inarray($DEV, @DEVS);
    my $outkey = "${DEV}.html";

    # add some info to the returned data for troubleshooting
    $output->{$DEV}->{'name'} = $DEV;
    $output->{$DEV}->{'path'} = $key;
    $output->{$DEV}->{'file'} = $outkey;
    $output->{'count'}++;

    # retrieve configuration
    my $config = $s3->GetObject(Bucket=>$bucket, Key=>$key)->Body;

    # generate and write html
    $s3->PutObject(
      Bucket=>$output_bucket,
      ContentType=>"text/html",
      Key=>$outkey,
      Body=>generate_html(parse($config))
    );
  }
  return $output;
}

[...]
```

## Conclusion

This was surprisingly a lot of work to figure out.  I was puzzled by
quite a few things, until I finally just read the [code][bootstrappm]
for `AWS::Lambda`'s `bootstrap.pm`.  At one point, I thought that using
`Paws` might be overkill, so I explored a few other simpler S3 perl
modules, but did not get any working as well.

Using a perl lambda is certainly a good tool to have in my toolchest,
and I learned a lot building this.  If I were doing it again, though,
I think I'd more seriously consider spending the time and effort on
rewriting it in python.  At this point it feels like that may have
been a better investment in the future of the tool.  When I eventually
_do_ rewrite it, I'll compare that experience with the time I put in
for this, about a week of my spare time, and be able to make a better
comparison and judgement.

[bootstrappm]: https://metacpan.org/release/SHOGO/AWS-Lambda-0.0.29/source/lib/AWS/Lambda/Bootstrap.pm
