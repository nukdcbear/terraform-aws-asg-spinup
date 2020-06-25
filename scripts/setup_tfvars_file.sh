#!/bin/bash

# Going to us hostname variable for env_name in script in order to take advantage of existing terraform-apply slash command GitHub action
hostname=${hostname:-domo-dev}
route53_hosted_zone_name=${domain_name:-davidcbarringer.com}

while [ $# -gt 0 ]; do

    case "$1" in
        --hostname=*)
          hostname="${1#*=}"
          ;;
        --domain_name=*)
          route53_hosted_zone_name="${1#*=}"
          ;;
        *)
          printf "***************************\n"
          printf "* Error: Invalid argument.*\n"
          printf "***************************\n"
          exit 1
        esac
    shift
done

echo -e "env_name = \"$hostname\"\nroute53_hosted_zone_name = \"$route53_hosted_zone_name\"\n" > myterraform.tfvars
