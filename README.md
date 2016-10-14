# rs-premium_free_trial

This repository holds cloud application templates and any supporting artifacts related to the RightScale Premium Free Trial account offering.

Cloud Application Templates (CATs) provide full end-to-end automation and orchestration for n-tier applications.
The Premium Free Trial account CATs are designed to be fully self-sufficient in that they will automate everything needed
for successful launch including importing needed ServerTemplates, creation and management of servers, security groups, placement groups, etc.
Therefore, they can be easily imported into any RightScale Self-Service catalog and they should work.

Note the following:
- The CATs will use default networks in the given public clouds. If you want the CAT to use your specific networks or zones you need to modify the CAT accordingly.
- The CATs assume the VMware environment is named "POC vSphere" and have a zone named "POC-vSPhere-Zone-1." 
- The CATs are provided with no explicit or implicit promise of service. Use at your own risk.

INSTALLATION NOTES:
First, upload (but don't publish) the "pkg" files (in CATs/library).
They should be uploaded in this order:
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_common_mappings.pkg.rb  
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_common_LAMP_mappings.pkg.rb  
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_common_parameters.pkg.rb    
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_common_LAMP_parameters.pkg.rb    
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_common_conditions.pkg.rb    
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_common_resources.pkg.rb
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_common_LAMP_resources.pkg.rb
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_common_outputs.pkg.rb   
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_util_clouds.pkg.rb
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_util_creds.pkg.rb
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_util_err.pkg.rb
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_util_servertemplates.pkg.rb
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_util_serverarray.pkg.rb
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_util_account.pkg.rb
    pkg /Users/mitchellgerdisch/git/rs-premium_free_trial/CATs/library/lib_util_LAMP.pkg.rb

Then, upload and publish the "cat" files (in any order).