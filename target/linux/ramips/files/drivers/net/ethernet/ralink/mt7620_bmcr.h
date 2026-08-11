/* SPDX-License-Identifier: GPL-2.0-only */

#ifndef _RALINK_MT7620_BMCR_H
#define _RALINK_MT7620_BMCR_H

#ifdef __KERNEL__
#include <linux/types.h>
#include <linux/mii.h>
#else
#include <stdbool.h>
#include <stdint.h>

#define u16 uint16_t
#define BMCR_ANENABLE 0x1000
#define BMCR_ANRESTART 0x0200
#define BMCR_PDOWN 0x0800
#endif

static inline u16 mt7620_bmcr_set_enable(u16 bmcr, bool enable)
{
	if (enable)
		return (bmcr & ~BMCR_PDOWN) | BMCR_ANENABLE | BMCR_ANRESTART;

	return bmcr | BMCR_PDOWN;
}

#endif
