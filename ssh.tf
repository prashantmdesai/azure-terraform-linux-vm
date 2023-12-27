#https://www.youtube.com/watch?v=dLxkeMZXQEM
# Command to connect to the Linux VM
# ssh -i /Users/pdesai/Library/CloudStorage/OneDrive-ENDAVA/dev/azure-terraform-linux-vm/linuxkey.pem azureadmin@172.190.56.68

resource "tls_private_key" "linux_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#We want to save the private key to our machine
#so that we can use it to connect to our Linux VM

resource "local_file" "private_key" {
  content  = tls_private_key.linux_key.private_key_pem
  filename = "linuxkey.pem"
}