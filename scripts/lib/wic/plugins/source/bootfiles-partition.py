#
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Minimal WIC source plugin that populates a VFAT partition from
# a separate variable (IMAGE_BOOT_PARTITION_FILES) so it can coexist
# with IMAGE_BOOT_FILES used by bootimg-partition on another partition.
#

import logging
import os
import re

from glob import glob

from wic import WicError
from wic.pluginbase import SourcePlugin
from wic.misc import exec_cmd, get_bitbake_var

logger = logging.getLogger('wic')


class BootfilesPartitionPlugin(SourcePlugin):
    """
    Populate a boot partition with files listed in
    IMAGE_BOOT_PARTITION_FILES (same syntax as IMAGE_BOOT_FILES).
    """

    name = 'bootfiles-partition'

    @classmethod
    def do_configure_partition(cls, part, source_params, cr, cr_workdir,
                               oe_builddir, bootimg_dir, kernel_dir,
                               native_sysroot):
        hdddir = "%s/boot.%d" % (cr_workdir, part.lineno)
        exec_cmd("install -d %s" % hdddir)

        if not kernel_dir:
            kernel_dir = get_bitbake_var("DEPLOY_DIR_IMAGE")
            if not kernel_dir:
                raise WicError("Couldn't find DEPLOY_DIR_IMAGE, exiting")

        boot_files = get_bitbake_var("IMAGE_BOOT_PARTITION_FILES")
        if not boot_files:
            raise WicError("IMAGE_BOOT_PARTITION_FILES is not set")

        deploy_files = []
        for src_entry in re.findall(r'[\w;\-\./\*]+', boot_files):
            if ';' in src_entry:
                dst_entry = tuple(src_entry.split(';'))
                if not dst_entry[0] or not dst_entry[1]:
                    raise WicError('Malformed boot file entry: %s' % src_entry)
            else:
                dst_entry = (src_entry, src_entry)
            deploy_files.append(dst_entry)

        cls.install_task = []
        for src, dst in deploy_files:
            if '*' in src:
                entry_name_fn = os.path.basename
                if dst != src:
                    entry_name_fn = lambda name: os.path.join(dst, os.path.basename(name))
                for entry in glob(os.path.join(kernel_dir, src)):
                    cls.install_task.append((os.path.relpath(entry, kernel_dir),
                                            entry_name_fn(entry)))
            else:
                cls.install_task.append((src, dst))

    @classmethod
    def do_prepare_partition(cls, part, source_params, cr, cr_workdir,
                              oe_builddir, bootimg_dir, kernel_dir,
                              rootfs_dir, native_sysroot):
        hdddir = "%s/boot.%d" % (cr_workdir, part.lineno)

        if not kernel_dir:
            kernel_dir = get_bitbake_var("DEPLOY_DIR_IMAGE")
            if not kernel_dir:
                raise WicError("Couldn't find DEPLOY_DIR_IMAGE, exiting")

        for src_path, dst_path in cls.install_task:
            install_cmd = "install -m 0644 -D %s %s" \
                          % (os.path.join(kernel_dir, src_path),
                             os.path.join(hdddir, dst_path))
            exec_cmd(install_cmd)

        part.prepare_rootfs(cr_workdir, oe_builddir, hdddir,
                            native_sysroot, False)
