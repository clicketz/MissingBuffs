local _, ns = ...

-- NPC raid buffs (e.g. 432661) haven't been whitelisted yet by Blizzard
-- so they will return nil when queried by GetUnitAuraBySpellID. Not going
-- to provide a workaround in hopes that Blizzard fixes it themselves.
ns.RAID_BUFFS = {
    MAGE = { 1459, 432778 },
    WARRIOR = { 6673 },
    DRUID = { 1126, 432661 },
    PRIEST = { 21562 },
    SHAMAN = { 462854 },
    EVOKER = { 381748 }
}

ns.EVOKER_AURA_MAP = {
    DEATHKNIGHT = 381732,
    DEMONHUNTER = 381741,
    DRUID = 381746,
    EVOKER = 381748,
    HUNTER = 381749,
    MAGE = 381750,
    MONK = 381751,
    PALADIN = 381752,
    PRIEST = 381753,
    ROGUE = 381754,
    SHAMAN = 381756,
    WARLOCK = 381757,
    WARRIOR = 381758
}
