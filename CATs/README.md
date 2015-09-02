# customer_cat_pocs

*** POC_updates_withpgworkaround Branch Notes ***
Currently the placementgroup resource type is not supported. 
It's expected to be supported around Aug 5.
However, the updated CATs which take advantage of other features that are available now 
are being tested with a work-around which basically doesn't launch to Azure
which is where placement groups are needed.
Once the placementgroup resource type is supported, all one has to do is uncomment the resource declaration and
put Azure back in the allowed clouds.

CATs used for the POC in a Box offering.

These CATs make certain assumptions:
- They are fully portable. If a CAT needs something to exist in Cloud Management (e.g. ServerTemplate, SSH key), they import or otherwise create it as part of the CAT itself.
- They use standard cloud names and network offerings. If used in an environment that requires using specific networks, etc they will need some modifications (at this time).
- They are purposely simple and self-contained so that customers can quickly understand how to use them.
- Some CATs are examples only and are designed to raise errors - they are there to illustrate the breadth of what we can do.

