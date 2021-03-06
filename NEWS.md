# AzureVM 2.2.2

- Change maintainer email address.

# AzureVM 2.2.1

- Hotfix to previous version, to export `windows_2019_gen2` and `windows_2019_gen2_ss` configuration functions.

# AzureVM 2.2.0

- Add ability to retrieve an SSH public key from an Azure resource object. See `?user_config` for more information.
- New predefined configurations for VMs and VM scalesets: Ubuntu 20.04; Debian 10 (w/backports); Centos 8.1; RHEL 8.1 and 8.2; Windows Server 2019. All new configurations except Centos are available as both generation 1 and generation 2 VMs. See `?vm_config` and `?vmss_config` for more information.
  - The default configuration for `create_vm` and `create_vm_scaleset` now uses Ubuntu 20.04.
- Update the DSVM configuration functions `ubuntu_dsvm` and `windows_dsvm` to use the latest images. The Ubuntu DSVM no longer has a built-in data disk, so the `dsvm_disk_type` argument has been removed.
  - New `ubuntu_dsvm_gen2` configuration to create a gen2 Ubuntu DSVM.
- Fix a bug that prevented Windows scalesets from being created.
- Logic to detect a running VM now correctly handles VMs that are updating.
- Assorted other minor fixes.

# AzureVM 2.1.1

- Require R6 2.4.1, which is needed to allow cloning of active bindings in R 4.0.
- The `low_priority` argument to `scaleset_options` is now simply `priority`, with a default of "regular" and an alternative of "spot". Spot VMs are the replacement for low-priority VMs; seee [this page](https://azure.microsoft.com/en-us/pricing/spot/) for more details. Note that you can use the same argument to create a single (non-scaleset) spot VM, with `create_vm(*, properties=list(priority="spot"))`.

# AzureVM 2.1.0

* VM scalesets can now be created with data disks.
* Make OS disk type and Linux DSVM data disk type selectable, with a default of "Premium_LRS" for both.
* Background process pool functionality moved into AzureRMR; this removes code duplication and makes it available for other packages that can benefit.
* `managed` argument to `create_vm/vmss`, `vm/vmss_config` and related methods changed to `managed_identity`, to make its meaning clearer. Due to partial matching of function arguments, this should not affect any user code.

# AzureVM 2.0.1

* Add methods to retrieve Azure resources used by a VM: `get_disk`, `get_vnet`, `get_nic`, `get_nsg`, `get_public_ip_resource`. These return objects of class `AzureRMR::az_resource`, or `NULL` if not present.
* Add similar methods to retrieve Azure resources used by a scaleset: `get_vnet`, `get_nsg`, `get_public_ip_resource`, `get_load_balancer`, `get_autoscaler`.
* Add `redeploy` and `reimage` methods for VMs, to match those for VM scalesets.
* Fix error in documentation for VMSS public IP address methods: these return `NA`, not `NULL` if the public address is unavailable.

# AzureVM 2.0.0

* Complete rewrite of package, to be less DSVM-centric and more flexible:
  * Separate out deployment of VMs and VM clusters; the latter are implemented as scalesets, rather than simplistic arrays of individual VMs. The methods to work with scalesets are named `get_vm_scaleset`, `create_vm_scaleset` and `delete_vm_scaleset`; `get/create/delete_vm_cluster` are now defunct.
  * New UI for VM/scaleset creation, with many more ways to fine-tune the deployment options, including specifying the base VM image; networking details like security rules, load balancers and autoscaling; datadisks to attach; use of low-priority VMs for scalesets; etc.
  * Several predefined configurations supplied to allow quick deployment of commonly used images (Ubuntu, Windows Server, RHEL, Debian, Centos, DSVM).
  * Allow referring to existing resources in a deployment (eg placing VMs into an existing vnet), by supplying `AzureRMR::az_resource` objects as arguments.
  * Clear distinction between a VM deployment template and a resource. `get_vm` and `get_vm_scaleset` will always attempt to retrieve the template; to get the resource, use `get_vm_resource` and `get_vm_scaleset_resource`.
  * New VM resource methods: `get_public_ip_address`, `get_private_ip_address`.
  * New cluster/scaleset resource methods: `get_public_ip_address` (technically the address for the load balancer, if present), `get_vm_public_ip_addresses`, `get_vm_private_ip_addresses`, `list_instances`, `get_instance`.
  * Use a pool of background processes to talk to scalesets in parallel when carrying out instance operations. The pool size can be controlled with the global options `azure_vm_minpoolsize` and `azure_vm_maxpoolsize`.
  * See the README and/or the vignette for more information.

# AzureVM 1.0.1

* Allow resource group and subscription accessor methods to work without AzureVM on the search path.

# AzureVM 1.0.0

* Submitted to CRAN

# AzureVM 0.9.0

* Moved to cloudyr organisation
