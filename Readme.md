Quick and dirty Raspberry PI virtual machine for development


    ./pi_qemu_build.sh /path/to/raspbian_install.img base.qcow2  # <-- creates base.qcow2 and snapshot.qcow2
    ./pi_qemu_run.sh snapshot.img   # <-- now update the setup application and set pi password, etc., reboot and π's your uncle
