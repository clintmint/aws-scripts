#!/bin/bash

export AWS_PROFILE=AdministratorAccess-123456789012
if [ -f ~/.aws/config ] && grep -q $AWS_PROFILE ~/.aws/config; then 
    echo "Using AWS CLI profile '${AWS_PROFILE}'"
else
    echo "AWS CLI profile '${AWS_PROFILE}' not detected, exiting." && exit 1
fi
export SG=default

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'

for region in $(aws ec2 describe-regions --query "Regions[].{Name:RegionName}" --output text)
do
    export AWS_DEFAULT_REGION=$region

    # API calls could be blocked by AWS Org SCP for entire regions. If auth error, skip region.
    if aws ec2 describe-security-groups --output json --group-name "$SG" --query "SecurityGroups[0].IpPermissions" &>/dev/null; then
        INGRESS_RULES=$(aws ec2 describe-security-groups --output json --group-name "$SG" --query "SecurityGroups[0].IpPermissions")
        if [ "$INGRESS_RULES" != "[]" ]; then
            aws ec2 revoke-security-group-ingress --group-name "$SG" --ip-permissions "$INGRESS_RULES" 1>/dev/null && echo -e "${RED}Ingress rules deleted in $region${RED}"
        else
            echo -e "${GREEN}No ingress rules detected in $region${GREEN}"
        fi

        SG_ID=$(aws ec2 describe-security-groups --output text --group-name "$SG" --query "SecurityGroups[0].GroupId")

        EGRESS_RULES=$(aws ec2 describe-security-groups --output json --group-name "$SG" --query "SecurityGroups[0].IpPermissionsEgress")
        if [ "$EGRESS_RULES" != "[]" ]; then
            aws  ec2 revoke-security-group-egress --group-id "$SG_ID" --ip-permissions "$EGRESS_RULES" 1>/dev/null && echo -e "${RED}Egress rules deleted in $region${RED}"
        else
            echo -e "${GREEN}No egress rules detected in $region${GREEN}"
        fi
    else
        echo -e "${YELLOW}API calls are blocked in $region, skipping.${YELLOW}"
    fi
done