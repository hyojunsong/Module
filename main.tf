resource "azurerm_resource_group" "RG" {
  name          = var.RG-name[count.index]
  location      = var.RG-location
  count         = var.coun
  tags          = var.tag
}

resource "azurerm_virtual_network" "VN" {
  name                  = var.VN-name[count.index]
  resource_group_name   = azurerm_resource_group.RG[count.index].name
  location              = azurerm_resource_group.RG[count.index].location
  count                 = var.coun
  address_space         = [var.VN-address[count.index]]
  tags                  = var.tag
}

resource "azurerm_subnet" "Subnet" {
  name                  = var.sub-name[count.index]
  resource_group_name   = azurerm_resource_group.RG[count.index].name
  virtual_network_name  = azurerm_virtual_network.VN[count.index].name
  count                 = var.coun
  address_prefixes      = [var.sub-add[count.index]]
}

#Public_ip
resource "azurerm_public_ip" "Public_ip" {
    name                = var.Public_ip_name[count.index]
    resource_group_name = azurerm_resource_group.RG[count.index].name
    location            = azurerm_resource_group.RG[count.index].location
    count               = var.coun
    allocation_method   = "Dynamic"
    tags                = var.tag
}

#Network_InterFace_Card_Static
resource "azurerm_network_interface" "NIC_Static" {
    name                  = var.Static_NIC_name[count.index]
    resource_group_name   = azurerm_resource_group.RG[count.index].name
    location              = azurerm_resource_group.RG[count.index].location
    count = var.coun

    ip_configuration {
      name                                  = "S-Nic_ip"
      subnet_id                             = azurerm_subnet.Subnet[count.index].id
      private_ip_address_allocation         = "Static" 
      private_ip_address                    = var.private_ip_add[count.index]
      public_ip_address_id                  = azurerm_public_ip.Public_ip[count.index].id
    }
    tags                                    = var.tag
}

#Virtual_Machine
resource "azurerm_virtual_machine" "VM" {
    name                    = var.vm_name[count.index]
    count = var.coun
    resource_group_name = azurerm_resource_group.RG[count.index].name
    location            = azurerm_resource_group.RG[count.index].location
    network_interface_ids   = [ azurerm_network_interface.NIC_Static[count.index].id ]
    vm_size                 = "Standard_D2s_v3"

    storage_image_reference {
      publisher     = "MicrosoftWindowsDesktop"
      offer         = "Windows-10"
      sku           = "20h2-ent-g2"
      version       = "latest"
    }

    storage_os_disk {
      name                  = var.os_name[count.index]
      caching               = "ReadWrite"
      create_option         = "FromImage"
      managed_disk_type     = "Premium_LRS"
    }

    os_profile {
      computer_name     = var.computer_name[count.index]
      admin_username    = var.user_name[count.index]
      admin_password    = var.user_password[count.index]
    }

    os_profile_windows_config {
      #disable_password_authentication = false
    }
    tags = var.tag
}

resource "azurerm_public_ip" "CGD-LB-Public" {
  name                = "CDG_Pu-LB"
  location            = azurerm_resource_group.RG[count.index].location
  resource_group_name = azurerm_resource_group.RG[count.index].name
  count = var.coun
  allocation_method   = "Static"
  sku = "Standard"
  tags = var.tag
 }


resource "azurerm_lb" "CGD-LB" {
  name                = var.CGD-LB-name[count.index]
  location            = azurerm_resource_group.RG[count.index].location
  resource_group_name = azurerm_resource_group.RG[count.index].name
  count = var.coun
  sku = "Standard"
  frontend_ip_configuration {
    name                 = "CGD_frontend"
    public_ip_address_id = azurerm_public_ip.CGD-LB-Public[count.index].id
  }

############################################################################

resource "azurerm_lb_backend_address_pool" "CGD-Backend" {
  loadbalancer_id = azurerm_lb.CGD-LB[count.index].id
  count = var.coun
  name            = "Backend_pool"
}

resource "azurerm_lb_backend_address_pool_address" "add-a" {
  name                    = var.backend-add-name[count.index]
  backend_address_pool_id = azurerm_lb_backend_address_pool.CGD-Backend[count.index].id
  virtual_network_id      = azurerm_virtual_network.VN[count.index].id
  count = var.coun
  ip_address = var.backend-ip-add[count.index]
}

resource "azurerm_lb_probe" "CGD-probe" {
 loadbalancer_id     = azurerm_lb.CGD-LB[count.index].id
 count = var.coun
 name                = "CGD-probe"
 port                = "80"
}

resource "azurerm_lb_rule" "CGD-rule" {
  count = var.coun
  loadbalancer_id                = azurerm_lb.CGD-LB[count.index].id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  probe_id                       = azurerm_lb_probe.CGD-probe[count.index].id
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.CGD-Backend[count.index].id ]
  frontend_ip_configuration_name = "CGD_frontend"
}

resource "azurerm_network_security_group" "NSG" {
  count = var.coun
  name = var.NSG-name[count.index]
  location = var.RG-location
  resource_group_name = var.RG-name[count.index]
  tags = var.tag
  security_rule {
    name                       = var.security_rule_name[count.index]
    priority                   = var.security_rule_priority[count.index]
    direction                  = var.security_rule_direction[count.index]
    access                     = var.security_rule_access[count.index]
    protocol                   = var.security_rule_protocol[count.index]
    source_port_range          = var.security_rule_source_port_range[count.index]
    destination_port_range     = var.security_rule_destination_port_range[count.index]
    source_address_prefix      = var.security_rule_source_address_prefix[count.index]
    destination_address_prefix = var.security_rule_destination_address_prefix[count.index]
  }
}
resource "azurerm_network_interface_security_group_association" "join" {
  count = var.coun
  network_interface_id = azurerm_network_interface.NIC_Static[count.index].id
  network_security_group_id = azurerm_network_security_group.NSG[count.index].id
}