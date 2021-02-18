#!/bin/bash
# update the CDN identifier in the hugo config

set -euxo pipefail

CDN_ID=$(terraform output -raw cloudfront_distribution_id)
CONFIG="../config.yaml"

sed -i "" "/^\([[:space:]]*cloudFrontDistributionID: \).*/s//\1$CDN_ID/" $CONFIG
