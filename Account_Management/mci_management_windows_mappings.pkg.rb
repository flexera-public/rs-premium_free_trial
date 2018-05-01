name "LIB - MCI Management - Windows Mappings"
rs_ca_ver 20160622
short_description "Mappings related to Windows MCI management."

package "pft/mci/windows_mappings"

# mappings of starting MCI to clone from
mapping "map_mci_info" do {
  "2008R2" => {
    "base_mci_name" => "Windows_Server_Datacenter_2008R2_x64",
    "custom_mci_name" => "PFT Windows_Server_2008R2_x64"
  },
  "2012R2" => {
    "base_mci_name" => "Windows_Server_Standard_2012R2_x64",
    "custom_mci_name" => "PFT Windows_Server_2012R2_x64"
  }
} end

# Mappings of image name for each of the support clouds.
# A rudimentary regexp capability is supported to help narrow down the image to use.
# The assumption is that the given image name root is searched with leading and trailing anchors: /^STRING$/.
# However, you can add a trailing regexp, in delineated by open and closing arrows, "<< >>", to handle cases where the name changes over time.
# Note the need to escape any backslashes.
mapping "map_image_name_root" do {
  "2008R2" => {
    "AWS" => "Windows_Server-2008-R2_SP1-English-64Bit-Base-<<\\d{4}\\.\\d{2}\\.\\d{2}>>",
    "AzureRM" => "MicrosoftWindowsServer WindowsServer 2008-R2-SP1 latest",
    "Google" => "windows-server-2008-r2-latest",
  },
  "2012R2" => {
    "AWS" => "Windows_Server-2012-R2_RTM-English-64Bit-Base-<<\\d{4}\\.\\d{2}\\.\\d{2}>>",
    "AzureRM" => "MicrosoftWindowsServer WindowsServer 2012-R2-Datacenter latest",
    "Google" => "windows-server-2012-r2-latest",
  },
} end