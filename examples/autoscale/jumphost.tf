module "jumpvpc" {
  source = "../../modules/vpc"
  networks = [
    {
      name            = "pso-customer-panorama"
      subnetwork_name = "pso-customer-panorama-jumphost"
      create_network  = false
      ip_cidr_range   = "192.168.13.0/24"
    },
  ]
  region = "europe-west4"
}

# Spawn the VM-series firewall as a Google Cloud Engine Instance.
module "jumphost" {
  source = "../../modules/vmseries"
  instances = {
    "as4-jumphost01" = {
      name = "as4-jumphost01"
      zone = "europe-west4-c"
      network_interfaces = [
        {
          subnetwork = try(module.vpc.subnetworks[var.jumphost_network].self_link, null)
          public_nat = true
        },
      ]
    }
  }
  ssh_key         = "admin:${file(var.public_key_path)}"
  image_uri       = "https://console.cloud.google.com/compute/imagesDetail/projects/nginx-public/global/images/nginx-plus-centos7-developer-v2019070118"
  service_account = module.iam_service_account.email
}

output jumphost_ssh_command {
  value = module.jumphost.nic0_public_ips
}

resource null_resource jumphost_ssh_priv_key {
  connection {
    type        = "ssh"
    user        = "admin"
    private_key = file(var.private_key_path)
    host        = module.jumphost.nic0_public_ips["as4-jumphost01"]
  }

  provisioner "file" {
    source      = var.private_key_path
    destination = "key"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod go-rwx -R key",
      "echo 'Manage firewalls:    ssh  -i key  admin@internal_ip_of_firewall'",
    ]
  }
}
