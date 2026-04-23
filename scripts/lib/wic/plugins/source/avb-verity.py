#
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# DESCRIPTION
# WIC source plugin that builds a compact rootfs image with an AVB
# (Android Verified Boot) hashtree footer appended right after the
# filesystem using avb_sign.  The footer contains a signed Merkle hash
# tree with a PKCS#7 root hash signature that enables dm-verity
# integrity verification at runtime via avb_verify and dmsetup.
# The image is not padded to partition size, making it compatible
# with LUKS containers.
#
# Required bitbake variables:
#   AVB_SIGN_KEY       : path to the private key (PEM) for signing
#   AVB_X509           : path to the X.509 certificate
#
# Optional bitbake variables:
#   AVB_ALGORITHM      : signing algorithm (default: SHA256_RSA4096)
#   AVB_HASH_ALGORITHM : hash algorithm    (default: sha256)
#
#

import logging
import os
import shutil
import sys

from oe.path import copyhardlinktree

from wic import WicError
from wic.pluginbase import SourcePlugin
from wic.misc import get_bitbake_var, exec_cmd, exec_native_cmd

logger = logging.getLogger('wic')


class AVBVerityPlugin(SourcePlugin):

    name = 'avb-verity'

    @staticmethod
    def __get_rootfs_dir(rootfs_dir):
        if os.path.isdir(rootfs_dir):
            return os.path.realpath(rootfs_dir)

        image_rootfs_dir = get_bitbake_var("IMAGE_ROOTFS", rootfs_dir)
        if not os.path.isdir(image_rootfs_dir):
            raise WicError("No valid artifact IMAGE_ROOTFS from image "
                           "named %s has been found at %s, exiting." %
                           (rootfs_dir, image_rootfs_dir))

        return os.path.realpath(image_rootfs_dir)

    @classmethod
    def do_prepare_partition(cls, part, source_params, cr, cr_workdir,
                             oe_builddir, bootimg_dir, kernel_dir,
                             krootfs_dir, native_sysroot):
        """
        Prepare partition content by reusing the rootfs image produced by
        the standard prepare_rootfs() path and then appending an AVB
        hashtree footer to it using avbtool.
        """
        if part.rootfs_dir is None:
            if 'ROOTFS_DIR' not in krootfs_dir:
                raise WicError("Couldn't find --rootfs-dir, exiting")
            rootfs_dir = krootfs_dir['ROOTFS_DIR']
        else:
            if part.rootfs_dir in krootfs_dir:
                rootfs_dir = krootfs_dir[part.rootfs_dir]
            elif part.rootfs_dir:
                rootfs_dir = part.rootfs_dir
            else:
                raise WicError("Couldn't find --rootfs-dir=%s connection or "
                               "it is not a valid path, exiting" % part.rootfs_dir)

        part.rootfs_dir = cls.__get_rootfs_dir(rootfs_dir)

        # Resolve pseudo directory for preserving file ownership and xattrs
        image_rootfs = get_bitbake_var("IMAGE_ROOTFS")
        if image_rootfs:
            pseudo_dir = os.path.join(os.path.dirname(os.path.realpath(image_rootfs)), "pseudo")
        else:
            pseudo_dir = None
        if pseudo_dir and not os.path.lexists(pseudo_dir):
            logger.warning("pseudo dir %s does not exist "
                           "file ownership, permissions and xattrs will be lost" % pseudo_dir)
            pseudo_dir = None

        new_rootfs = None
        # Handle excluded paths.
        if part.exclude_path is not None:
            new_rootfs = os.path.realpath(
                os.path.join(cr_workdir, "rootfs%d" % part.lineno))

            if os.path.lexists(new_rootfs):
                shutil.rmtree(new_rootfs)

            copyhardlinktree(part.rootfs_dir, new_rootfs)

            for orig_path in part.exclude_path:
                path = orig_path
                if os.path.isabs(path):
                    logger.error("Must be relative: --exclude-path=%s"
                                 % orig_path)
                    sys.exit(1)

                full_path = os.path.realpath(
                    os.path.join(new_rootfs, path))

                if not full_path.startswith(new_rootfs):
                    logger.error("'%s' points to a path outside the rootfs"
                                 % orig_path)
                    sys.exit(1)

                if path.endswith(os.sep):
                    for entry in os.listdir(full_path):
                        full_entry = os.path.join(full_path, entry)
                        if os.path.isdir(full_entry) \
                                and not os.path.islink(full_entry):
                            shutil.rmtree(full_entry)
                        else:
                            os.remove(full_entry)
                else:
                    shutil.rmtree(full_path)

        #  determine filesystem size
        # The AVB footer is placed right after the filesystem
        # (--partition_size 0) so avb-verify can find it by scanning
        # from the end of the file/block device.
        algorithm = get_bitbake_var("AVB_ALGORITHM") or "SHA256_RSA4096"
        hash_algorithm = get_bitbake_var("AVB_HASH_ALGORITHM") or "sha256"

        # build the filesystem image
        # Let prepare_rootfs() auto-size the filesystem to fit content.
        # The AVB hashtree + footer are appended after the filesystem,
        # and the compact image must fit inside the GPT partition
        # (and inside LUKS after encryption).
        # When --fixed-size is set in WKS, the auto-sizing attributes
        # (extra_space, overhead_factor) are None — provide defaults.
        orig_fixed_size = part.fixed_size
        orig_extra_space = part.extra_space
        orig_overhead_factor = part.overhead_factor
        part.fixed_size = 0
        part.extra_space = part.extra_space or 0
        part.overhead_factor = part.overhead_factor or 1.0

        # dm-verity uses 4096-byte data blocks; for ext4 the filesystem
        # block size must be >= the verity block size or the kernel will
        # refuse to mount ("bad block size").  erofs/squashfs are always
        # 4K-aligned so no fixup needed for those.
        orig_mkfs_extraopts = part.mkfs_extraopts
        if part.fstype and part.fstype.startswith("ext"):
            if part.mkfs_extraopts:
                if "-b " not in part.mkfs_extraopts:
                    part.mkfs_extraopts += " -b 4096"
            else:
                part.mkfs_extraopts = "-F -i 8192 -b 4096"

        part.prepare_rootfs(cr_workdir, oe_builddir,
                            new_rootfs or part.rootfs_dir, native_sysroot,
                            pseudo_dir=pseudo_dir)

        # Restore original values for the GPT partition entry
        part.fixed_size = orig_fixed_size
        part.extra_space = orig_extra_space
        part.overhead_factor = orig_overhead_factor
        part.mkfs_extraopts = orig_mkfs_extraopts

        rootfs_img = part.source_file
        logger.info("Rootfs image for avb-verity: %s (size %d bytes)"
                    % (rootfs_img, os.path.getsize(rootfs_img)))

        # append AVB hashtree footer
        sign_key = get_bitbake_var("AVB_SIGN_KEY")
        part_name = part.label or part.part_name or "rootfs"

        if not sign_key:
            raise WicError("AVB_SIGN_KEY must be set to the path of the "
                           "RSA private key for AVB signing")

        if not os.path.isfile(sign_key):
            raise WicError("AVB signing key not found: %s" % sign_key)

        logger.info("avb-verity: algorithm=%s, partition=%s"
                    % (algorithm, part_name))

        avb_x509 = get_bitbake_var("AVB_X509") or ""

        avb_output = os.path.join(cr_workdir, "avb-verity-output.img")

        avb_cmd = ("avb_sign "
                   "--image %s "
                   "--output %s "
                   "--key %s "
                   "--cert %s "
                   "--partition-name %s "
                   "--algorithm %s"
                   % (rootfs_img, avb_output, sign_key,
                      avb_x509, part_name, algorithm))

        _, output = exec_native_cmd(avb_cmd, native_sysroot)
        logger.info("avb_sign output:\n%s" % output)

        shutil.move(avb_output, rootfs_img)

        avb_image_bytes = os.path.getsize(rootfs_img)
        logger.info("avb-verity: compact image size %d bytes"
                    % avb_image_bytes)

        # The image is compact (filesystem + hashtree + footer, no padding).
        # WIC uses part.fixed_size for the GPT entry; part.size controls
        # how many bytes are actually written.
        part.size = (avb_image_bytes + 1023) // 1024
        part.source_file = rootfs_img
