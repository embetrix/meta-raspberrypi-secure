# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

# Only Raspberry Pi 4/5 family machines are supported
RPI_SECURE_SUPPORTED_MACHINES = "raspberrypi4-64 raspberrypi5 raspberrypi-cm5-io-board"

python () {
    supported = d.getVar('RPI_SECURE_SUPPORTED_MACHINES').split()
    machine = d.getVar('MACHINE')
    if machine not in supported:
        bb.fatal("%s is not supported by this layer: Supported machines: %s" % (machine, ', '.join(supported)))
}
