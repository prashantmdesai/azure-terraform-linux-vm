# Quickstart: Use Terraform to create a Linux VM
# https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-terraform?tabs=azure-cli


resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

#Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

#Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}


#Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "myPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

#Create network security group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

    security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "myNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

#Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

#Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}


#Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


#Create virtual machine
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  name                  = "myVM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = "Standard_DS11_v2"



  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  computer_name  = "chandamama"
  admin_username = var.username

  admin_ssh_key {
    username   = var.username
    public_key = tls_private_key.linux_key.public_key_openssh
  }


  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }

  depends_on = [
    azurerm_network_interface.my_terraform_nic,
    tls_private_key.linux_key
  ]

# Reference video for creation of the RDP connection to the Ubuntu machine
# https://www.youtube.com/watch?v=T1JQ8RIRMt4

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get -y install xfce4",
      "sudo apt install xfce4-session",
      "sudo apt-get -y install xrdp",
      "sudo systemctl enable xrdp",
      "sudo adduser xrdp ssl-cert",
      "echo xfce4-session >~/.xsession",
      "sudo service xrdp restart",
      "sudo apt-get update",
      "sudo apt install firefox"
    ]
  }

# To install chrome manually
# "wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb",
# "sudo dpkg -i google-chrome-stable_current_amd64.deb",
# "sudo apt -f install",

connection {
   host        = coalesce(self.public_ip_address)
   agent       = true
   type        = "ssh"
   user        = var.username
   private_key = file(pathexpand(local_file.private_key.filename))
  }

}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "vmshutdownschedule" {
    virtual_machine_id = azurerm_linux_virtual_machine.my_terraform_vm.id
    location = azurerm_resource_group.rg.location
    enabled = true

    daily_recurrence_time = "1700"
    timezone = "Eastern Standard Time"

notification_settings {
    enabled = true
    email = "prashantmdesai@hotmail.com"
    }
}


#https://www.youtube.com/watch?v=dLxkeMZXQEM
# Command to connect to the Linux VM
# ssh -i /Users/pdesai/Library/CloudStorage/OneDrive-ENDAVA/dev/azure-terraform-linux-vm/linuxkey.pem azureadmin@172.190.56.68


#Command to change the azureadmin password
#sudo passwd azureadmin

#Commands to install chrome
#sudo apt-get update
#wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
#sudo dpkg -i google-chrome-stable_current_amd64.deb
#sudo apt -f install


#Command to copy file from remote ubuntu VM
# sudo scp -i /Users/pdesai/Library/CloudStorage/OneDrive-ENDAVA/dev/azure-terraform-linux-vm/linuxkey.pem azureadmin@172.191.101.134:/home/azureadmin/Downloads/download.jpeg /Users/pdesai/Downloads/

#Command to copy file to remote ubuntu VM
#sudo scp -i /Users/pdesai/Library/CloudStorage/OneDrive-ENDAVA/dev/azure-terraform-linux-vm/linuxkey.pem /Users/pdesai/Downloads/download.html azureadmin@172.191.101.134:/home/azureadmin/Downloads/

