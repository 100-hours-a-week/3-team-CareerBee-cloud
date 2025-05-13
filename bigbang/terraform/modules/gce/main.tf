resource "google_compute_instance" "vm_instance" {
  for_each = { for inst in var.instances : inst.name => inst }

  name         = each.value.name
  machine_type = each.value.machine_type
  zone         = each.value.zone

  boot_disk {
    initialize_params {
      image = each.value.boot_image
      size  = each.value.boot_disk_size_gb
      type  = each.value.boot_disk_type
    }
  }

  network_interface {
    network    = each.value.network
    subnetwork = each.value.subnetwork

    access_config {
      nat_ip = lookup(each.value, "nat_ip", null)
    }
  }

  tags         = each.value.tags
  metadata     = each.value.metadata
  
  service_account {
    email  = each.value.service_account_email
    scopes = each.value.scopes
  }
  allow_stopping_for_update = true

  scheduling {
    on_host_maintenance = "TERMINATE"
  }

  dynamic "attached_disk" {
    for_each = lookup(each.value, "attached_disks", [])
    content {
      source      = attached_disk.value.source
      device_name = lookup(attached_disk.value, "device_name", null)
      mode        = lookup(attached_disk.value, "mode", "READ_WRITE")
    }
  }
}