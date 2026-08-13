#include <assert.h>
#include <stdint.h>

#include "../../target/linux/ramips/files/drivers/net/ethernet/ralink/mt7620_bmcr.h"

static void test_disable_preserves_bits(void)
{
	const uint16_t before = 0x4521;
	const uint16_t after = mt7620_bmcr_set_enable(before, false);

	assert(after == (uint16_t)(before | BMCR_PDOWN));
	assert((after & (uint16_t)~BMCR_PDOWN) ==
	       (before & (uint16_t)~BMCR_PDOWN));
}

static void test_enable_restarts_autonegotiation(void)
{
	const uint16_t before = BMCR_PDOWN | 0x4021;
	const uint16_t after = mt7620_bmcr_set_enable(before, true);

	assert(!(after & BMCR_PDOWN));
	assert(after & BMCR_ANENABLE);
	assert(after & BMCR_ANRESTART);
	assert((after & (uint16_t)~(BMCR_PDOWN | BMCR_ANENABLE |
					 BMCR_ANRESTART)) ==
	       (before & (uint16_t)~(BMCR_PDOWN | BMCR_ANENABLE |
					 BMCR_ANRESTART)));
}

static void test_idempotence(void)
{
	const uint16_t before = 0x0021;
	const uint16_t down = mt7620_bmcr_set_enable(before, false);
	const uint16_t up = mt7620_bmcr_set_enable(down, true);

	assert(mt7620_bmcr_set_enable(down, false) == down);
	assert(mt7620_bmcr_set_enable(up, true) == up);
}

static void test_mdio_read_errors(void)
{
	assert(mt7620_mii_read_failed((uint32_t)-1));
	assert(mt7620_mii_read_failed(0xffff));
	assert(!mt7620_mii_read_failed(0x1140));
}

int main(void)
{
	test_disable_preserves_bits();
	test_enable_restarts_autonegotiation();
	test_idempotence();
	test_mdio_read_errors();
	return 0;
}
