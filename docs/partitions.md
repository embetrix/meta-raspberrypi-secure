# Partition Layout

## Overview

## Partition Table

Set partition sizes in `local.conf` using WIC size values with a unit suffix
(for example, `M` for MiB or `G` for GiB). The defaults are:

```bitbake
ROOT_PART_SZ ?= "1024M"
DATA_PART_SZ ?= "4096M"
```

`ROOT_PART_SZ` sets the fixed size of each root partition (`rootA` and `rootB`).
`DATA_PART_SZ` sets the fixed size of the `data` partition.

## A/B Slots

## Data Partitions

## Filesystem Types

## References
