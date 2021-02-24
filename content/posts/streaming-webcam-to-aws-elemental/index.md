---
title: "Streaming webcam to aws elemental"
date: 2021-02-24
tags:
  - tags here
categories:
  - categories here
showToc: true
TocOpen: false
draft: true
hidemeta: false
comments: false
description: |
  My description
  goes here
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "cover.jpg"
    alt: "Alt Text"
    caption: "[title](source link) by [author](profile link) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

## Install software

[https://camstreamer.com/release-notes](https://camstreamer.com/release-notes)

Exacq / vO3sQaX4

1. Download CamStreamer App 3.10-6
2. on camera admin page, shoose Applicatinos
3. "choose file" and "upload package"
4. Double click on "CamStreamer App" in Installed Applications list
5. License
6. Configure

## Configure AWS

[https://aws.amazon.com/blogs/media/part1-how-to-send-live-video-to-aws-elemental-mediastore/](https://aws.amazon.com/blogs/media/part1-how-to-send-live-video-to-aws-elemental-mediastore/)

### Create AWS Elemental MediaStore Container

1. [https://console.aws.amazon.com/mediastore/](https://console.aws.amazon.com/mediastore/)
2. click on "Create Container", name it "Hubbard-webcam-test"

### Set container policy to allow public access

1. select container, and choose "container policy", adding the following:

```json
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"PublicReadOverHttpOrHttps",
      "Effect":"Allow",
      "Principal":"*",
      "Action":[
        "mediastore:GetObject",
        "mediastore:DescribeObject"
      ],
      "Resource":"arn:aws:mediastore:us-east-1:251453624780:container/Hubbard-webcam-test/*",
      "Condition":{
        "Bool":{
          "aws:SecureTransport":[
            "true",
            "false"
          ]
        }
      }
    }
  ]
}
```

### Set CORS policy to specific domains

1. Click on "Container CORS policy"
2. Click on "Apply Default Policy", accept warning.
3. To limit access, replace "*" in "AllowedOrigins" with domain(s) of
   sites which will include the video.

### create MediaLive encoder input

[https://console.aws.amazon.com/medialive](https://console.aws.amazon.com/medialive)

1. Click "Create Channel"
2. Click "Inputs", "Create Input"
3. Settings:

Name: "RTMP_Input"
Type: "RTMP (push)"
Network mode: "Public"  (will be VPC for endpoint networking over DX)
Input Security group: "0.0.0.0/0"  (will be list of camera IPs)
Input Destinations: "Standard Input"
Destination A: "stream1", and "a"
Destination B: "stream2", and "b"
Tags: empty (for now)

### Create the MediaLive channel

1. Click on "channels", "Create Channel"
2. Name it "webcam-test"
3. IAM role "create role from template"
4. Use "Live Event" template
5. Add input attachment defined earlier
6. Edit HLS output group, set destination URL to data endpoint for mediastore
   created above.
   (append `/livea/main` and `/liveb/main` to dest a and b, respectively)
7. Click "Create Channel"

### TODO

- SG
- VPCE
- auth?
- tf
- pricing
- embed
- CORS

### Notes

- there is no terraform resource to medialive
- try cf?
