# rs-premium_free_trial

This repository holds cloud application templates and any supporting artifacts related to the RightScale Premium Free Trial account offering.

Cloud Application Templates (CATs) provide full end-to-end automation and orchestration for n-tier applications.
The Premium Free Trial account CATs are designed to be fully self-sufficient in that they will automate everything needed
for successful launch including importing needed ServerTemplates, creation and management of servers, security groups, placement groups, etc.
Therefore, they can be easily imported into any RightScale Self-Service catalog and they should work.

Note the following:
- The CATs will use default networks in the given public clouds. If you want the CAT to use your specific networks or zones you need to modify the CAT accordingly.
  - One caveat is AzureRM, where PFT specific networks (named `pft_arm_network`) are created by running the `PFT Admin CAT - PFT Network Setup` CAT located in the `Account_Management` directory.
- The CATs are provided with no explicit or implicit promise of service. Use at your own risk.

# INSTALLATION NOTES:

## Prerequsites
While the `pftv2_bootstrap.sh` script (described below) handles most of the prerequisites, there are two things you'll need to do manually.

1) Import the Chef Server base ServerTemplate from the marketplace. This is necessary because the user must accept a EULA, something we can not do programatically. http://www.rightscale.com/library/server_templates/Chef-Server-for-Linux-RightLin/lineage/57238

2) Create a credential named `PFT_RS_REFRESH_TOKEN` with an oAuth refresh token that is scoped to the target account.

### Bootstrap script
The `pftv2_bootstrap.sh` script is intended to automate as much as possible to install and configure the PFT assets.

Most notably, there are several library CAT files which must be uploaded in a particular order. This is handled by the `cats` option of the bootstrap script.

Also, several prerequisite objects (MCIs, networks, cloned ServerTemplates, etc) are created by running the management CATs. This is handled by the `management` option of the bootstrap script.

```
Usage: pftv2_bootstrap.sh [options]
  options:
    all - Does bootstrapping of all following items. This is the default if no option is set
    cats - Upserts all libraries and application cats
    sts - Upserts all ServerTemplates
    management - Launches management CATs for creating networks, MCI, and STs
    schedule - Creates a 'Business Hours' CAT schedule
    publish - Publishes the CATs to the Self-Service catalog with the "Business Hours" (and "Always On") schedules.
The following environment variables must be set. OAUTH_REFRESH_TOKEN, ACCOUNT_ID, SHARD_HOSTNAME
```
