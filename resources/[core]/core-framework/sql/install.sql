-- specs/frd-core-framework.md - Data Requirements
CREATE TABLE IF NOT EXISTS characters (
  identifier   VARCHAR(60)  NOT NULL PRIMARY KEY,        -- FiveM license identifier
  name         VARCHAR(60)  NOT NULL DEFAULT 'Unknown',
  cash         INT          NOT NULL DEFAULT 0,
  bank         INT          NOT NULL DEFAULT 0,
  job          VARCHAR(50)  NOT NULL DEFAULT 'unemployed', -- placeholder for Increment 2
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);
