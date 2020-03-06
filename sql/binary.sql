-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');
-- succeeds, textual plugin, textual consumer
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'force_binary', '0');
-- fails, binary plugin, textual consumer
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'force_binary', '1');
-- succeeds, textual plugin, binary consumer
SELECT data FROM pg_logical_slot_get_binary_changes('regression_slot', NULL, NULL, 'force_binary', '0');
-- succeeds, binary plugin, binary consumer
SELECT data FROM pg_logical_slot_get_binary_changes('regression_slot', NULL, NULL, 'force_binary', '1');

SELECT 'init' FROM pg_drop_replication_slot('regression_slot');
