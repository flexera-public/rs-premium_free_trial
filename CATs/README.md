# Available Stacks
This section describes the available Cloud Automation Templates (CATs)

| Stack Name | Main CAT File | Description |
|--------------|-----|---------------|
| Linux Server | LinuxServer.cat.rb | Launches one or more Linux Servers sized based on user selection. |
| Windows Server | WindowServer.cat.rb | Launches one or more Windows Servers configured with a user-specified local admin account. |
| LAMP Stack | RL10LampStack.cat.rb | Launches and configures a Chef server and then launches a 3-tier LAMP stack orchestrated to use the Chef Server for the tiers' roles. |
| Least Expensive Cloud | LeastExpensiveCloudPlacement.cat.rb | Launches one or more Linux servers in the least expensive cloud based on user-specified CPU and RAM requirements. |
| Docker with WordPress | DockerWordPress.cat.rb | Launches a Docker host and orchestrates a WordPress and DB containers on the Docker Host to provide a WordPress stack. |
| Rancher Cluster | RancherCluster.cat.rb | Launches a Rancher cluster and provides the user the ability to launch WordPress and Nginx stacks on the cluster. |


# Cloud Application Templates Assumptions and Notes
The Cloud Application Templates (CATs) in this repository are used for the RightScale Premium Free Trial (PFT) offering.

These CATs make certain assumptions:
- They are fully portable. If a CAT needs something to exist in Cloud Management (e.g. ServerTemplate, SSH key), they import or otherwise create it as part of the CAT itself.
- They use standard cloud names and network offerings. If used in an environment that requires using specific networks, etc they will need some modifications (at this time).
- They are purposely self-contained so that customers can use them in their own environments with little or no modifications.

INSTALLATION NOTES:
See the README file under the root folder.
