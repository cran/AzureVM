% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/vm_resource_config.R
\name{user_config}
\alias{user_config}
\alias{datadisk_config}
\alias{image_config}
\title{Resource configuration functions for a virtual machine deployment}
\usage{
user_config(username, sshkey = NULL, password = NULL)

datadisk_config(size, name = "datadisk", create = "empty",
  type = c("StandardSSD_LRS", "Premium_LRS", "Standard_LRS", "UltraSSD_LRS"),
  write_accelerator = FALSE)

image_config(publisher = NULL, offer = NULL, sku = NULL,
  version = "latest", id = NULL)
}
\arguments{
\item{username}{For \code{user_config}, the name for the admin user account.}

\item{sshkey}{For \code{user_config}, the SSH public key. This can be supplied in a number of ways: as a string with the key itself; the name of the public key file; or an \code{AzureRMR::az_resource} object pointing to an SSH public key resource (of type "Microsoft.Compute/sshPublicKeys"). See the examples below.}

\item{password}{For \code{user_config}, the admin password. Supply either \code{sshkey} or \code{password}, but not both; also, note that Windows does not support SSH logins.}

\item{size}{For \code{datadisk_config}, the size of the data disk in GB. St this to NULL for a disk that will be created from an image.}

\item{name}{For \code{datadisk_config}, the disk name. Duplicate names will automatically be disambiguated prior to VM deployment.}

\item{create}{For \code{datadisk_config}, the creation method. Can be "empty" (the default) to create a blank disk, or "fromImage" to use an image.}

\item{type}{For \code{datadisk_config}, the disk type (SKU). Can be "Standard_LRS", "StandardSSD_LRS" (the default), "Premium_LRS" or "UltraSSD_LRS". Of these, "Standard_LRS" uses hard disks and the others use SSDs as the underlying hardware.}

\item{write_accelerator}{For \code{datadisk_config}, whether the disk should have write acceleration enabled.}

\item{publisher, offer, sku, version}{For \code{image_config}, the details for a marketplace image.}

\item{id}{For \code{image_config}, the resource ID for a disk to use as a custom image.}
}
\description{
Resource configuration functions for a virtual machine deployment
}
\examples{
\dontrun{

## user_config: SSH public key resource in Azure
# create the resource
keyres <- rg$create_resource(type="Microsoft.Compute/sshPublicKeys", name="mysshkey")

# generate the public and private keys
keys <- keyres$do_operation("generateKeyPair", http_verb="POST")
keyres$sync_fields()

# save the private key (IMPORTANT)
writeBin(keys$privateKey, "mysshkey.pem")

# create a new VM using the public key resource for authentication
# you can then login to the VM with ssh -i mysshkey.pem <username@vmaddress>
rg$create_vm("myvm", user_config("username", sshkey=keyres), config="ubuntu_20.04")


## user_config: SSH public key as a file
rg$create_vm("myvm", user_config("username", sshkey="mysshkey.pub"), config="ubuntu_20.04")


## user_config: SSH public key as a string (read from a file)
pubkey <- readLines("mysshkey.pub")
rg$create_vm("myvm", user_config("username", sshkey=pubkey), config="ubuntu_20.04")

}

}
