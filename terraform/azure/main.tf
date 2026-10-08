terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = "00000000-0000-0000-0000-000000000000"
  tenant_id       = "11111111-1111-1111-1111-111111111111"
  client_id       = "22222222-2222-2222-2222-222222222222"
  client_secret   = "Xq8Q~acmeDemoClientSecretValue.000000000"
}

resource "azurerm_resource_group" "main" {
  name     = "acme-prod"
  location = "East US"
}

resource "azurerm_storage_account" "data" {
  name                            = "acmeproddata"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  enable_https_traffic_only       = false
  min_tls_version                 = "TLS1_0"
  allow_nested_items_to_be_public = true
  shared_access_key_enabled       = true
  public_network_access_enabled   = true

  network_rules {
    default_action = "Allow"
  }
}

resource "azurerm_storage_container" "invoices" {
  name                  = "invoices"
  storage_account_name  = azurerm_storage_account.data.name
  container_access_type = "container"
}

resource "azurerm_network_security_group" "web" {
  name                = "web-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-rdp"
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
    name                       = "allow-all"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_key_vault" "main" {
  name                       = "acme-prod-kv"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = "11111111-1111-1111-1111-111111111111"
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  enable_rbac_authorization  = false

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  access_policy {
    tenant_id = "11111111-1111-1111-1111-111111111111"
    object_id = "33333333-3333-3333-3333-333333333333"

    secret_permissions      = ["Get", "List", "Set", "Delete", "Purge", "Recover", "Backup", "Restore"]
    key_permissions         = ["Get", "List", "Create", "Delete", "Purge", "Decrypt", "Encrypt"]
    certificate_permissions = ["Get", "List", "Delete", "Purge"]
  }
}

resource "azurerm_key_vault_secret" "db" {
  name         = "db-password"
  value        = "P@ssw0rd1234"
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_mssql_server" "main" {
  name                          = "acme-sql-prod"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "12.0"
  administrator_login           = "sqladmin"
  administrator_login_password  = "P@ssw0rd1234"
  minimum_tls_version           = "1.0"
  public_network_access_enabled = true
}

resource "azurerm_mssql_firewall_rule" "all" {
  name             = "AllowAll"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

resource "azurerm_mssql_database" "app" {
  name      = "acme"
  server_id = azurerm_mssql_server.main.id
  transparent_data_encryption_enabled = false
}

resource "azurerm_kubernetes_cluster" "main" {
  name                              = "acme-aks"
  location                          = azurerm_resource_group.main.location
  resource_group_name               = azurerm_resource_group.main.name
  dns_prefix                        = "acme"
  role_based_access_control_enabled = false
  local_account_disabled            = false
  private_cluster_enabled           = false
  api_server_authorized_ip_ranges   = []

  default_node_pool {
    name                = "default"
    node_count          = 3
    vm_size             = "Standard_D4s_v3"
    enable_node_public_ip = true
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
  }
}

resource "azurerm_linux_virtual_machine" "legacy" {
  name                            = "legacy-app"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_B2s"
  admin_username                  = "azureuser"
  admin_password                  = "Password1234!"
  disable_password_authentication = false
  network_interface_ids           = []
  encryption_at_host_enabled      = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_role_assignment" "vm_owner" {
  scope                = "/subscriptions/00000000-0000-0000-0000-000000000000"
  role_definition_name = "Owner"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

resource "azurerm_linux_web_app" "portal" {
  name                = "acme-portal"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/acme-prod/providers/Microsoft.Web/serverFarms/acme-plan"
  https_only          = false

  site_config {
    minimum_tls_version = "1.0"
    ftps_state          = "AllAllowed"
    remote_debugging_enabled = true
    cors {
      allowed_origins     = ["*"]
      support_credentials = false
    }
  }

  auth_settings {
    enabled = false
  }

  app_settings = {
    "DB_CONNECTION" = "Server=acme-sql-prod.database.windows.net;User Id=sqladmin;Password=P@ssw0rd1234;Encrypt=False"
  }
}
