#' Virtual machine cluster template class
#'
#' Class representing a virtual machine template. This class keeps track of all resources that are created as part of deploying a VM or cluster of VMs, and exposes methods for managing them. In this page, "VM" refers to both a cluster of virtual machines, as well as a single virtual machine (which is treated as the special case of a cluster containing a single node).
#'
#' @docType class
#' @section Methods:
#' The following methods are available, in addition to those provided by the [AzureRMR::az_template] class:
#' - `new(...)`: Initialize a new VM object. See 'Initialization' for more details.
#' - `start(wait=TRUE)`: Start the VM. By default, wait until the startup process is complete.
#' - `stop(deallocate=TRUE, wait=FALSE)`: Stop the VM. By default, deallocate it as well.
#' - `restart(wait=TRUE)`: Restart the VM.
#' - `run_deployed_command(command, parameters, script)`: Run a PowerShell command on the VM.
#' - `run_script(script, parameters)`: Run a script on the VM. For a Linux VM, this will be a shell script; for a Windows VM, a PowerShell script. Pass the script as a character vector.
#' - `sync_vm_status()`: Update the VM status fields in this object with information from the host.
#' - `resize(size, deallocate=FALSE, wait=FALSE)`: Resize the VM. Optionally deallocate it first (may sometimes be necessary).
#'
#' @section Fields:
#' The following fields are available, in addition to those provided by the `AzureRMR::az_template` class. Each is a list with one element per node in the cluster.
#' - `disks`: The status of any attached disks.
#' - `ip_address`: The IP address. NULL if the node is currently deallocated.
#' - `dns_name`: The fully qualified domain name.
#' - `status`: The status of the node, giving the provisioning state and power state.
#'
#' @details
#' A single virtual machine in Azure is actually a collection of resources, including any and all of the following. A cluster can share a storage account and virtual network, but each individual node will still have its own IP address and network interface.
#' - Storage account
#' - Network interface
#' - Network security group
#' - Virtual network
#' - IP address
#' - The VM itself
#'
#' By wrapping the deployment template used to create these resources, the `az_vm_template` class allows managing them all as a single entity.
#'
#' @section Initialization:
#' Initializing a new object of this class can either retrieve an existing VM template, or deploy a new VM template on the host. Generally, the best way to initialize an object is via the VM-related methods of the [az_subscription] and [az_resource_group] class, which handle the details automatically.
#'
#' A new VM can be created in _exclusive_ mode, meaning a new resource group is created solely to hold the VM. This simplifies deleting a VM considerably, as deleting the resource group will also automatically delete all the VM's resources. This can be done asynchronously, meaning that the `delete()` method returns immediately while the process continues on the host. Otherwise, deleting a VM will explicitly delete each of its resources, a task that must be done synchronously to allow for dependencies.
#'
#' @seealso
#' [AzureRMR::az_resource], [create_vm], [create_vm_cluster], [get_vm], [get_vm_cluster], [list_vms],
#' [delete_vm], [delete_vm_cluster],
#' [VM API reference](https://docs.microsoft.com/en-us/rest/api/compute/virtualmachines)
#'
#' @examples
#' \dontrun{
#'
#' # recommended way to retrieve a VM: via a resource group or subscription object
#' sub <- AzureRMR::az_rm$
#'     new(tenant="myaadtenant.onmicrosoft.com", app="app_id", password="password")$
#'     get_subscription("subscription_id")
#' 
#' vm <- sub$get_vm("myLinuxDSVM")
#'
#' # start the VM
#' vm$start()
#'
#' # run a shell command
#' vm$run_script("ifconfig > /tmp/ifc.out")
#'
#' # stop (and deallocate) the VM
#' vm$stop()
#'
#' # resize the VM
#' vm$resize("Standard_DS13_v2")
#'
#' # get the VM status
#' vm$sync_vm_status()
#'
#' }
#' @format An R6 object of class `az_vm_template`, inheriting from `AzureRMR::az_template`.
#' @export
az_vm_template <- R6::R6Class("az_vm_template", inherit=az_template,

public=list(
    disks=NULL,
    status=NULL,
    ip_address=NULL,
    dns_name=NULL,
    clust_size=NULL,

    initialize=function(token, subscription, resource_group, name, ..., wait=TRUE)
    {
        super$initialize(token, subscription, resource_group, name, ..., wait=wait)

        # fill in fields that don't require querying the host
        num_instances <- self$properties$outputs$numInstances
        if(is_empty(num_instances))
        {
            self$clust_size <- 1
            vmnames <- self$name
        }
        else
        {
            self$clust_size <- as.numeric(num_instances$value)
            vmnames <- paste0(self$name, seq_len(self$clust_size) - 1)
        }

        if(wait)
        {
            private$vm <- sapply(vmnames, function(name)
            {
                az_vm_resource$new(self$token, self$subscription, self$resource_group,
                type="Microsoft.Compute/virtualMachines", name=name)
            }, simplify=FALSE)

            # get the hostname/IP address for the VM
            outputs <- unlist(self$properties$outputResources)
            ip_id <- grep("publicIPAddresses/.+$", outputs, ignore.case=TRUE, value=TRUE)
            ip <- lapply(ip_id, function(id)
                az_resource$new(self$token, self$subscription, id=id)$properties)

            self$ip_address <- sapply(ip, function(x) x$ipAddress)
            self$dns_name <- sapply(ip, function(x) x$dnsSettings$fqdn)

            lapply(private$vm, function(obj) obj$sync_vm_status())
            self$disks <- lapply(private$vm, "[[", "disks")
            self$status <- lapply(private$vm, "[[", "status")
            NULL
        }
        else message("Deployment started. Call the sync_vm_status() method to track the status of the deployment.")

        NULL
    },

    sync_vm_status=function()
    {
        if(is_empty(private$vm) || is_empty(self$status) || tolower(self$status[[1]][1]) != "succeeded")
        {
            res <- try(self$initialize(self$token, self$subscription, self$resource_group, self$name), silent=TRUE)
            if(inherits(res, "try-error"))
            {
                message("VM deployment in progress")
                return(invisible(NULL))
            }
        }

        lapply(private$vm, function(obj) obj$sync_vm_status())
        self$disks <- lapply(private$vm, "[[", "disks")
        self$status <- lapply(private$vm, "[[", "status")
        self$status
    },

    start=function(wait=TRUE)
    {
        lapply(private$get_vm(), function(obj) obj$start(wait=wait))
        self$sync_vm_status()
    },

    stop=function(deallocate=TRUE, wait=TRUE)
    {
        lapply(private$get_vm(), function(obj) obj$stop(deallocate=deallocate, wait=wait))
        self$sync_vm_status()
    },

    restart=function(wait=TRUE)
    {
        lapply(private$get_vm(), function(obj) obj$restart(wait=wait))
        self$sync_vm_status()
    },

    add_extension=function(...)
    {
        lapply(private$get_vm(), function(obj) obj$add_extension(...))
        invisible(NULL)
    },

    resize=function(size, deallocate=FALSE, wait=FALSE)
    {
        lapply(private$get_vm(), function(obj) obj$resize(size, deallocate=deallocate, wait=wait))
        invisible(NULL)
    },

    run_deployed_command=function(...)
    {
        lapply(private$get_vm(), function(obj) obj$run_deployed_command(...))
        invisible(NULL)
    },

    run_script=function(...)
    {
        lapply(private$get_vm(), function(obj) obj$run_script(...))
        invisible(NULL)
    },

    delete=function(confirm=TRUE, free_resources=TRUE)
    {
        # delete the resource group -- customised confirmation message
        if(self$properties$mode == "Complete" && confirm && interactive())
        {
            vmtype <- if(self$clust_size == 1) "VM" else "VM cluster"
            msg <- paste0("Do you really want to delete ", vmtype, " and resource group '", self$name, "'? (y/N) ")
            yn <- readline(msg)
            if(tolower(substr(yn, 1, 1)) != "y")
                return(invisible(NULL))
            super$delete(confirm=FALSE, free_resources=TRUE)
        }
        else
        {
            if(free_resources)
            {
                # delete individual resources

                if(confirm && interactive())
                {
                    vmtype <- if(self$clust_size == 1) "VM" else "VM cluster"
                    msg <- paste0("Do you really want to delete ", vmtype, " '", self$name, "'? (y/N) ")
                    yn <- readline(msg)
                    if(tolower(substr(yn, 1, 1)) != "y")
                        return(invisible(NULL))
                }

                lapply(private$vm, function(obj) obj$delete(confirm=FALSE, wait=TRUE))
                super$delete(confirm=FALSE, free_resources=TRUE)
            }
            else super$delete(confirm=confirm, free_resources=FALSE)
        }
    },

    print=function(...)
    {
        header <- "<Azure virtual machine "
        if(self$clust_size > 1)
            header <- paste0(header, "cluster ")
        cat(header, self$name, ">\n", sep="")

        osProf <- names(private$vm[[1]]$properties$osProfile)
        os <- if(any(grepl("linux", osProf))) "Linux" else if(any(grepl("windows", osProf))) "Windows" else "<unknown>"
        exclusive <- self$properties$mode == "Complete"
        dns_label <- if(self$clust_size == 1) "Domain name:" else "Domain names:"
        dns_names <- if(is_empty(self$dns_name))
            paste0("  ", dns_label, " <none>")
        else strwrap(paste(dns_label, paste0(self$dns_name, collapse=", ")),
                     width=0.8*getOption("width"), indent=2, exdent=4)

        cat("  Operating system:", os, "\n")
        cat("  Exclusive resource group:", exclusive, "\n")
        cat(paste0(dns_names, collapse="\n"), "\n", sep="")
        cat("  Status:")

        if(is_empty(self$status) || is_empty(self$status[[1]]))
            cat(" <unknown>\n")
        else
        {
            prov_status <- as.data.frame(do.call(rbind, self$status))
            row.names(prov_status) <- paste0("    ", row.names(prov_status))
            cat("\n")
            print(prov_status)
        }

        cat("---\n")

        exclude <- c("subscription", "resource_group", "name", "dns_name", "status")
        if(self$clust_size == 1)
            exclude <- c(exclude, "clust_size")
        cat(AzureRMR::format_public_fields(self, exclude=exclude))
        cat(AzureRMR::format_public_methods(self))
        invisible(NULL)
    }
),

private=list(
    vm=list(NULL),

    get_vm=function()
    {
        if(is_empty(private$vm))
            stop("VM deployment in progress", call.=FALSE)
        private$vm
    },

    sync_vm_resources=function()
    {
        private$vm <- sapply(vmnames, function(name)
        {
            az_vm_resource$new(self$token, self$subscription, self$resource_group,
                type="Microsoft.Compute/virtualMachines", name=name)
        }, simplify=FALSE)

        # get the hostname/IP address for the VM
        outputs <- unlist(self$properties$outputResources)
        ip_id <- grep("publicIPAddresses/.+$", outputs, ignore.case=TRUE, value=TRUE)
        ip <- lapply(ip_id, function(id)
            az_resource$new(self$token, self$subscription, id=id)$properties)

        self$ip_address <- sapply(ip, function(x) x$ipAddress)
        self$dns_name <- sapply(ip, function(x) x$dnsSettings$fqdn)

        lapply(private$vm, function(obj) obj$sync_vm_status())
        self$disks <- lapply(private$vm, "[[", "disks")
        self$status <- lapply(private$vm, "[[", "status")
        NULL
    }
))


#' Is an object an Azure VM template
#'
#' @param object an R object.
#'
#' @details
#' This function returns TRUE only for an object representing a VM template deployment. In particular, it returns FALSE for a raw VM resource.
#'
#' @return
#' A boolean.
#' @export
is_vm_template <- function(object)
{
    R6::is.R6(object) && inherits(object, "az_vm_template")
}


# arguments to this must be named
make_dsvm_param_list=function(...)
{
    params <- list(...)

    template <- tools::file_path_sans_ext(basename(params$template))
    parm_map <- param_mappings[[template]]

    # match supplied arguments to those expected by template
    params <- params[names(params) %in% names(parm_map)]
    names(params) <- parm_map[match(names(parm_map), names(params))]

    lapply(params, function(x) list(value=as.character(x)))
}


get_dsvm_template=function(os, userauth_type, clust_size, ext_file_uris, inst_command)
{
    if(os == "Ubuntu")
        template <- "ubuntu_dsvm"
    else if(os == "Windows")
        template <- "win2016_dsvm"
    else stop("Unknown OS: ", os, call.=FALSE)

    if(clust_size > 1)
        template <- paste0(template, "_cl")

    if(userauth_type == "key")
        template <- paste0(template, "_key")

    if(!is_empty(ext_file_uris) || !is_empty(inst_command))
        template <- paste0(template, "_ext")

    template <- system.file("templates", paste0(template, ".json"), package="AzureVM")
    if(template == "")
        stop("Unsupported combination of parameters", call.=FALSE)
    template
}