Config = Config or {}

-- Default name assigned to a newly created character (single-character
-- model for Increment 1 - no character creation/naming UI yet).
Config.DefaultCharacterName = 'Unknown'

-- How often connected characters are flushed to the database, in
-- addition to the immediate saves on disconnect and after every
-- balance-changing transaction (frd-core-framework.md FR5).
Config.SaveIntervalMs = 5 * 60 * 1000
