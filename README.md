# Packer-Virt-Sysprep

---

Scripts to clean and prepare a VM for cloning à la
[libguestfs](http://libguestfs.org)'s
[virt-sysprep](http://libguestfs.org/virt-sysprep.1.html) but from
within a *running* guest.

The intention is to provide
[virt-sysprep](http://libguestfs.org/virt-sysprep.1.html) style
**operations** such as log removal, removal of a guests host ssh keys,
deletion of custom firewall rules etc for use with automated build tools
such as [packer](http://www.packer.io).

Currently [libguestfs](http://libguestfs.org) is not available for all
host platforms. Additionally
[virt-sysprep](http://libguestfs.org/virt-sysprep.1.html) requires that
the guest VM be shutdown prior to use.

---

Please see the
[packer-virt-sysprep-example](https://github.com/DanHam/packer-virt-sysprep-example)
repository for example usage and further details.
