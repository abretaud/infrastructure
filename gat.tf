variable "count" {
  default = 10
}

variable "image" {
  default = "Ubuntu 20.04"
}

# Random passwords for the VMs, easier to type/remember for the non-ssh key
# users.
resource "random_pet" "training-vm" {
  keepers = {
    count = "${count.index}"
    image = "${var.image}"
  }

  length = 2
  count  = "${var.count}"
}

# The VMs themselves.
resource "openstack_compute_instance_v2" "training-vm" {
  name            = "gat-${count.index}.training.galaxyproject.eu"
  image_name      = "${var.image}"
  flavor_name     = "m1.xlarge"
  security_groups = ["public", "public-ping", "public-web2", "egress", "public-gat"]

  key_pair = "cloud2"

  network {
    name = "public"
  }

  # Update user password
  user_data = <<-EOF
    #cloud-config
    chpasswd:
      list: |
        ubuntu:${element(random_pet.training-vm.*.id, count.index)}
      expire: False
    runcmd:
     - [ sed, -i, s/PasswordAuthentication no/PasswordAuthentication yes/, /etc/ssh/sshd_config ]
     - [ systemctl, restart, ssh ]
  EOF

  count = "${var.count}"
}

# Setup a DNS record for the VMs to make access easier (and https possible.)
resource "aws_route53_record" "training-vm" {
  zone_id = "${aws_route53_zone.training-gxp-eu.zone_id}"
  name    = "gat-${count.index}.training.galaxyproject.eu"
  type    = "A"
  ttl     = "900"
  records = ["${element(openstack_compute_instance_v2.training-vm.*.access_ip_v4, count.index)}"]
  count   = "${var.count}"
}

# Only for the REAL gat.
#resource "aws_route53_record" "training-vm-gxit-wildcard" {
#zone_id = "${aws_route53_zone.training-gxp-eu.zone_id}"
#  name    = "*.interactivetoolentrypoint.interactivetool.gat-${count.index}.training.galaxyproject.eu"
#  type    = "CNAME"
#  ttl     = "900"
#  records = ["gat-${count.index}.training.galaxyproject.eu"]
#  count   = "${var.count}"
#}

# Outputs to be consumed by admins
output "training_ips" {
  value = ["${openstack_compute_instance_v2.training-vm.*.access_ip_v4}"]
}

output "training_pws" {
  value     = ["${random_pet.training-vm.*.id}"]
  sensitive = true
}

output "training_dns" {
  value = ["${aws_route53_record.training-vm.*.name}"]
}
