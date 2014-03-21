Quick and dirty Raspberry PI qemu virtual machine for development.

Tested on Debian Wheezy + qemu 1.7.0.

You probably need to apt-get a bunch of stuff first.

    ./pi_qemu_build.sh /path/to/raspbian_install.img base.qcow2  # <-- creates base.qcow2 and snapshot.qcow2
    ./pi_qemu_run.sh snapshot.qcow2
    # now update the setup application and set pi password, etc., reboot and π's your aunty.

See [this article](http://xecdesign.com/qemu-emulating-raspberry-pi-the-easy-way/) [1] for what these scripts automate, and for where the kernel image comes from.

 [1] http://xecdesign.com/qemu-emulating-raspberry-pi-the-easy-way/
