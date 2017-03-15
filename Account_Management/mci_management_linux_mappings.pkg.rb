name "LIB - MCI Management - Linux Mappings"
rs_ca_ver 20160622
short_description "Mappings related to Windows MCI management."

package "pft/mci/linux_mappings"

# mappings of starting MCI to clone from
mapping "map_mci_info" do {
  "PFT Base Linux" => {
    "base_mci_name" => "Ubuntu_14.04_x64",
    "custom_mci_name" => "PFT Base Linux MCI"
  },
  "PFT Ubuntu 16.04" => {
    "base_mci_name" => "Ubuntu_16.04_x64",
    "custom_mci_name" => "PFT Ubuntu 16.04"
  }
} end

# Mappings of image name for each of the support clouds.
# A rudimentary regexp capability is supported to help narrow down the image to use.
# The assumption is that the given image name root is searched with leading and trailing anchors: /^STRING$/.
# However, you can add a trailing regexp, in square brackets [ ], to handle cases where the name changes over time.
# Note the need to escape any backslashes.
mapping "map_image_name_root" do {
  "PFT Base Linux" => {
    "AWS" => "ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-<<\\d{8}>>",
    "AzureRM" => "Canonical UbuntuServer 14.04.0-LTS 14.04.<<\\d{8}\[0-9\]+>>", # it looks like it is a date yyyymmdd and then a number which I'm
    "Google" => "ubuntu-1404-trusty-v<<\\d{8}>>",
    "VMware" => "PFT_Ubuntu_vmware"
  },
  "PFT Ubuntu 16.04" => {
    "AWS" => "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-<<\\d{4}\\d{2}\\d{2}>>",
    "AzureRM" => "Canonical UbuntuServer 16.04.0-LTS 16.04.<<\\d{8}[0-9]+>>", # it looks like it is a date yyyymmdd and then a number which I'm
    "Google" => "ubuntu-1604-xenial-v<<\\d{8}>>",
  },
} end