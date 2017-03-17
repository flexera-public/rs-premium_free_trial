Scripts/CATs/Stuff related to setting up PFT accounts.
For example: Scripts for uploading the catalog. Or CATs used to manage the MCI, etc.
Basically admin stuff outside of the catalog that is published and made available in the PFT to the end uers.

Account Set Up Steps
- Create PFT_RS_REFRESH_TOKEN credential
    This is the OAUTH refresh token for a user with full access to the given account.
        Cloud Management Menu: Settings -> Accounts -> API Credentials
    For PFTs, see the PFT wookiee for the service account user to use for this.
- Import the "Chef Server for Linux (RightLink 10)" ServerTemplate (lineage: 57238).
- Run the pftv2_bootstrap.sh script 
    This script will execute all the steps to prep the account and upload the CATs
- Check Self Service catalog.
    If you don't see the CATs in the catalog, then publish them.