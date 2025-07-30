terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.37.0"
    }
  }
}

provider "azurerm" {
  features {}
  tenant_id       = "Input your tenant ID here"
  subscription_id = "Input your subscription ID here"
}

resource "azurerm_resource_group" "main" {
  name     = "rg-nadia-therapist-dev"
  location = "South East Asia"
  tags = {
    environment = "Development"
    CostCenter  = "AZ-NTT-DEV-01"
    ManagedBy   = "IT@Terraform"
  }
}

resource "azurerm_storage_account" "scripts" {
  name                     = "nadiastoragescript"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = azurerm_resource_group.main.tags
}

resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_id    = azurerm_storage_account.scripts.id
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "joindomain" {
  name                   = "joindomain.ps1"
  type                   = "Block"
  source                 = "${path.module}/scripts/joindomain.ps1"
  storage_account_name   = azurerm_storage_account.scripts.name
  storage_container_name = azurerm_storage_container.scripts.name
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-nadia-therapist-dev"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
  tags                = azurerm_resource_group.main.tags
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-nadia-therapist-dev"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPSOut"
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 100
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "vnet-nadia-therapist-dev-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "pip" {
  count               = 2
  name                = "pip-nadia-therapist-dev-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "nic-nadia-therapist-dev-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "vm-nic-${count.index}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_windows_virtual_machine" "main" {
  count                 = 2
  name                  = "vm-nadia-therapist-dev-${count.index}"
  computer_name         = "ntt-vm-dev${count.index}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  size                  = "Standard_B2ms"
  admin_username        = "Input your admin username here"
  admin_password        = "Input your admin password here"

  os_disk {
    name                 = "osdisk-nadia-therapist-dev-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-10"
    sku       = "win10-21h2-avd"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  enable_automatic_updates = true
  provision_vm_agent       = true
  tags                     = azurerm_resource_group.main.tags
}

resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  name                      = "hp-nadia-prod"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  type                      = "Pooled"
  maximum_sessions_allowed  = 15
  load_balancer_type        = "BreadthFirst"
  preferred_app_group_type  = "Desktop"
  friendly_name             = "Nadia AVD Host Pool"
  validate_environment      = true
  personal_desktop_assignment_type = "Automatic"
  start_vm_on_connect       = true
  custom_rdp_properties     = "audiocapturemode:i:1;audiomode:i:0;redirectprinters:i:1;"
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "token" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool.id
  expiration_date = timeadd(timestamp(), "24h")
}

resource "azurerm_virtual_desktop_application_group" "desktop" {
  name                = "dag-nadia-prod"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  host_pool_id        = azurerm_virtual_desktop_host_pool.hostpool.id
  type                = "Desktop"
  friendly_name       = "Desktop App Group"
}

resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = "ws-nadia-prod"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  friendly_name       = "Nadia Therapist AVD Workspace"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "link" {
  workspace_id         = azurerm_virtual_desktop_workspace.workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.desktop.id
}


