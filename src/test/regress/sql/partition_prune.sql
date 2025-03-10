--
-- Test partitioning planner code
--
create table lp (a char) partition by list (a);
create table lp_default partition of lp default;
create table lp_ef partition of lp for values in ('e', 'f');
create table lp_ad partition of lp for values in ('a', 'd');
create table lp_bc partition of lp for values in ('b', 'c');
create table lp_g partition of lp for values in ('g');
create table lp_null partition of lp for values in (null);
explain (costs off) select * from lp;
explain (costs off) select * from lp where a > 'a' and a < 'd';
explain (costs off) select * from lp where a > 'a' and a <= 'd';
explain (costs off) select * from lp where a = 'a';
explain (costs off) select * from lp where 'a' = a;	/* commuted */
explain (costs off) select * from lp where a is not null;
explain (costs off) select * from lp where a is null;
explain (costs off) select * from lp where a = 'a' or a = 'c';
explain (costs off) select * from lp where a is not null and (a = 'a' or a = 'c');
explain (costs off) select * from lp where a <> 'g';
explain (costs off) select * from lp where a <> 'a' and a <> 'd';
explain (costs off) select * from lp where a not in ('a', 'd');

-- collation matches the partitioning collation, pruning works
create table coll_pruning (a text collate "C") partition by list (a);
create table coll_pruning_a partition of coll_pruning for values in ('a');
create table coll_pruning_b partition of coll_pruning for values in ('b');
create table coll_pruning_def partition of coll_pruning default;
explain (costs off) select * from coll_pruning where a collate "C" = 'a' collate "C";
-- collation doesn't match the partitioning collation, no pruning occurs
explain (costs off) select * from coll_pruning where a collate "POSIX" = 'a' collate "POSIX";

create table rlp (a int, b varchar) partition by range (a);
create table rlp_default partition of rlp default partition by list (a);
create table rlp_default_default partition of rlp_default default;
create table rlp_default_10 partition of rlp_default for values in (10);
create table rlp_default_30 partition of rlp_default for values in (30);
create table rlp_default_null partition of rlp_default for values in (null);
create table rlp1 partition of rlp for values from (minvalue) to (1);
create table rlp2 partition of rlp for values from (1) to (10);

create table rlp3 (a int, b varchar) partition by list (b varchar_ops);
create table rlp3_default partition of rlp3 default;
create table rlp3abcd partition of rlp3 for values in ('ab', 'cd');
create table rlp3efgh partition of rlp3 for values in ('ef', 'gh');
create table rlp3nullxy partition of rlp3 for values in (null, 'xy');
alter table rlp attach partition rlp3 for values from (15) to (20);

create table rlp4 partition of rlp for values from (20) to (30) partition by range (a);
create table rlp4_default partition of rlp4 default;
create table rlp4_1 partition of rlp4 for values from (20) to (25);
create table rlp4_2 partition of rlp4 for values from (25) to (29);

create table rlp5 partition of rlp for values from (31) to (maxvalue) partition by range (a);
create table rlp5_default partition of rlp5 default;
create table rlp5_1 partition of rlp5 for values from (31) to (40);

explain (costs off) select * from rlp where a < 1;
explain (costs off) select * from rlp where 1 > a;	/* commuted */
explain (costs off) select * from rlp where a <= 1;
explain (costs off) select * from rlp where a = 1;
explain (costs off) select * from rlp where a = 1::bigint;		/* same as above */
explain (costs off) select * from rlp where a = 1::numeric;	/* no pruning */
explain (costs off) select * from rlp where a <= 10;
explain (costs off) select * from rlp where a > 10;
explain (costs off) select * from rlp where a < 15;
explain (costs off) select * from rlp where a <= 15;
explain (costs off) select * from rlp where a > 15 and b = 'ab';
explain (costs off) select * from rlp where a = 16;
explain (costs off) select * from rlp where a = 16 and b in ('not', 'in', 'here');
explain (costs off) select * from rlp where a = 16 and b < 'ab';
explain (costs off) select * from rlp where a = 16 and b <= 'ab';
explain (costs off) select * from rlp where a = 16 and b is null;
explain (costs off) select * from rlp where a = 16 and b is not null;
explain (costs off) select * from rlp where a is null;
explain (costs off) select * from rlp where a is not null;
explain (costs off) select * from rlp where a > 30;
explain (costs off) select * from rlp where a = 30;	/* only default is scanned */
explain (costs off) select * from rlp where a <= 31;
explain (costs off) select * from rlp where a = 1 or a = 7;
explain (costs off) select * from rlp where a = 1 or b = 'ab';

explain (costs off) select * from rlp where a > 20 and a < 27;
explain (costs off) select * from rlp where a = 29;
explain (costs off) select * from rlp where a >= 29;
explain (costs off) select * from rlp where a < 1 or (a > 20 and a < 25);

-- redundant clauses are eliminated
explain (costs off) select * from rlp where a > 1 and a = 10;	/* only default */
explain (costs off) select * from rlp where a > 1 and a >=15;	/* rlp3 onwards, including default */
explain (costs off) select * from rlp where a = 1 and a = 3;	/* empty */
explain (costs off) select * from rlp where (a = 1 and a = 3) or (a > 1 and a = 15);

-- multi-column keys
create table mc3p (a int, b int, c int) partition by range (a, abs(b), c);
create table mc3p_default partition of mc3p default;
create table mc3p0 partition of mc3p for values from (minvalue, minvalue, minvalue) to (1, 1, 1);
create table mc3p1 partition of mc3p for values from (1, 1, 1) to (10, 5, 10);
create table mc3p2 partition of mc3p for values from (10, 5, 10) to (10, 10, 10);
create table mc3p3 partition of mc3p for values from (10, 10, 10) to (10, 10, 20);
create table mc3p4 partition of mc3p for values from (10, 10, 20) to (10, maxvalue, maxvalue);
create table mc3p5 partition of mc3p for values from (11, 1, 1) to (20, 10, 10);
create table mc3p6 partition of mc3p for values from (20, 10, 10) to (20, 20, 20);
create table mc3p7 partition of mc3p for values from (20, 20, 20) to (maxvalue, maxvalue, maxvalue);

explain (costs off) select * from mc3p where a = 1;
explain (costs off) select * from mc3p where a = 1 and abs(b) < 1;
explain (costs off) select * from mc3p where a = 1 and abs(b) = 1;
explain (costs off) select * from mc3p where a = 1 and abs(b) = 1 and c < 8;
explain (costs off) select * from mc3p where a = 10 and abs(b) between 5 and 35;
explain (costs off) select * from mc3p where a > 10;
explain (costs off) select * from mc3p where a >= 10;
explain (costs off) select * from mc3p where a < 10;
explain (costs off) select * from mc3p where a <= 10 and abs(b) < 10;
explain (costs off) select * from mc3p where a = 11 and abs(b) = 0;
explain (costs off) select * from mc3p where a = 20 and abs(b) = 10 and c = 100;
explain (costs off) select * from mc3p where a > 20;
explain (costs off) select * from mc3p where a >= 20;
explain (costs off) select * from mc3p where (a = 1 and abs(b) = 1 and c = 1) or (a = 10 and abs(b) = 5 and c = 10) or (a > 11 and a < 20);
explain (costs off) select * from mc3p where (a = 1 and abs(b) = 1 and c = 1) or (a = 10 and abs(b) = 5 and c = 10) or (a > 11 and a < 20) or a < 1;
explain (costs off) select * from mc3p where (a = 1 and abs(b) = 1 and c = 1) or (a = 10 and abs(b) = 5 and c = 10) or (a > 11 and a < 20) or a < 1 or a = 1;
explain (costs off) select * from mc3p where a = 1 or abs(b) = 1 or c = 1;
explain (costs off) select * from mc3p where (a = 1 and abs(b) = 1) or (a = 10 and abs(b) = 10);
explain (costs off) select * from mc3p where (a = 1 and abs(b) = 1) or (a = 10 and abs(b) = 9);

-- a simpler multi-column keys case
create table mc2p (a int, b int) partition by range (a, b);
create table mc2p_default partition of mc2p default;
create table mc2p0 partition of mc2p for values from (minvalue, minvalue) to (1, minvalue);
create table mc2p1 partition of mc2p for values from (1, minvalue) to (1, 1);
create table mc2p2 partition of mc2p for values from (1, 1) to (2, minvalue);
create table mc2p3 partition of mc2p for values from (2, minvalue) to (2, 1);
create table mc2p4 partition of mc2p for values from (2, 1) to (2, maxvalue);
create table mc2p5 partition of mc2p for values from (2, maxvalue) to (maxvalue, maxvalue);

explain (costs off) select * from mc2p where a < 2;
explain (costs off) select * from mc2p where a = 2 and b < 1;
explain (costs off) select * from mc2p where a > 1;
explain (costs off) select * from mc2p where a = 1 and b > 1;

-- all partitions but the default one should be pruned
explain (costs off) select * from mc2p where a = 1 and b is null;
explain (costs off) select * from mc2p where a is null and b is null;
explain (costs off) select * from mc2p where a is null and b = 1;
explain (costs off) select * from mc2p where a is null;
explain (costs off) select * from mc2p where b is null;

-- boolean partitioning
create table boolpart (a bool) partition by list (a);
create table boolpart_default partition of boolpart default;
create table boolpart_t partition of boolpart for values in ('true');
create table boolpart_f partition of boolpart for values in ('false');

explain (costs off) select * from boolpart where a in (true, false);
explain (costs off) select * from boolpart where a = false;
explain (costs off) select * from boolpart where not a = false;
explain (costs off) select * from boolpart where a is true or a is not true;
explain (costs off) select * from boolpart where a is not true;
explain (costs off) select * from boolpart where a is not true and a is not false;
explain (costs off) select * from boolpart where a is unknown;
explain (costs off) select * from boolpart where a is not unknown;

create table boolrangep (a bool, b bool, c int) partition by range (a,b,c);
create table boolrangep_tf partition of boolrangep for values from ('true', 'false', 0) to ('true', 'false', 100);
create table boolrangep_ft partition of boolrangep for values from ('false', 'true', 0) to ('false', 'true', 100);
create table boolrangep_ff1 partition of boolrangep for values from ('false', 'false', 0) to ('false', 'false', 50);
create table boolrangep_ff2 partition of boolrangep for values from ('false', 'false', 50) to ('false', 'false', 100);

-- try a more complex case that's been known to trip up pruning in the past
explain (costs off)  select * from boolrangep where not a and not b and c = 25;

-- test scalar-to-array operators
create table coercepart (a varchar) partition by list (a);
create table coercepart_ab partition of coercepart for values in ('ab');
create table coercepart_bc partition of coercepart for values in ('bc');
create table coercepart_cd partition of coercepart for values in ('cd');

explain (costs off) select * from coercepart where a in ('ab', to_char(125, '999'));
explain (costs off) select * from coercepart where a ~ any ('{ab}');
explain (costs off) select * from coercepart where a !~ all ('{ab}');
explain (costs off) select * from coercepart where a ~ any ('{ab,bc}');
explain (costs off) select * from coercepart where a !~ all ('{ab,bc}');

drop table coercepart;

CREATE TABLE part (a INT, b INT) PARTITION BY LIST (a);
CREATE TABLE part_p1 PARTITION OF part FOR VALUES IN (-2,-1,0,1,2);
CREATE TABLE part_p2 PARTITION OF part DEFAULT PARTITION BY RANGE(a);
CREATE TABLE part_p2_p1 PARTITION OF part_p2 DEFAULT;
INSERT INTO part VALUES (-1,-1), (1,1), (2,NULL), (NULL,-2),(NULL,NULL);
EXPLAIN (COSTS OFF) SELECT tableoid::regclass as part, a, b FROM part WHERE a IS NULL ORDER BY 1, 2, 3;

--
-- some more cases
--

--
-- pruning for partitioned table appearing inside a sub-query
--
-- pruning won't work for mc3p, because some keys are Params
explain (costs off) select * from mc2p t1, lateral (select count(*) from mc3p t2 where t2.a = t1.b and abs(t2.b) = 1 and t2.c = 1) s where t1.a = 1;

-- pruning should work fine, because values for a prefix of keys (a, b) are
-- available
explain (costs off) select * from mc2p t1, lateral (select count(*) from mc3p t2 where t2.c = t1.b and abs(t2.b) = 1 and t2.a = 1) s where t1.a = 1;

-- also here, because values for all keys are provided
explain (costs off) select * from mc2p t1, lateral (select count(*) from mc3p t2 where t2.a = 1 and abs(t2.b) = 1 and t2.c = 1) s where t1.a = 1;

--
-- pruning with clauses containing <> operator
--

-- doesn't prune range partitions
create table rp (a int) partition by range (a);
create table rp0 partition of rp for values from (minvalue) to (1);
create table rp1 partition of rp for values from (1) to (2);
create table rp2 partition of rp for values from (2) to (maxvalue);

explain (costs off) select * from rp where a <> 1;
explain (costs off) select * from rp where a <> 1 and a <> 2;

-- null partition should be eliminated due to strict <> clause.
explain (costs off) select * from lp where a <> 'a';

-- ensure we detect contradictions in clauses; a can't be NULL and NOT NULL.
explain (costs off) select * from lp where a <> 'a' and a is null;
explain (costs off) select * from lp where (a <> 'a' and a <> 'd') or a is null;

-- check that it also works for a partitioned table that's not root,
-- which in this case are partitions of rlp that are themselves
-- list-partitioned on b
explain (costs off) select * from rlp where a = 15 and b <> 'ab' and b <> 'cd' and b <> 'xy' and b is not null;

--
-- different collations for different keys with same expression
--
create table coll_pruning_multi (a text) partition by range (substr(a, 1) collate "POSIX", substr(a, 1) collate "C");
create table coll_pruning_multi1 partition of coll_pruning_multi for values from ('a', 'a') to ('a', 'e');
create table coll_pruning_multi2 partition of coll_pruning_multi for values from ('a', 'e') to ('a', 'z');
create table coll_pruning_multi3 partition of coll_pruning_multi for values from ('b', 'a') to ('b', 'e');

-- no pruning, because no value for the leading key
explain (costs off) select * from coll_pruning_multi where substr(a, 1) = 'e' collate "C";

-- pruning, with a value provided for the leading key
explain (costs off) select * from coll_pruning_multi where substr(a, 1) = 'a' collate "POSIX";

-- pruning, with values provided for both keys
explain (costs off) select * from coll_pruning_multi where substr(a, 1) = 'e' collate "C" and substr(a, 1) = 'a' collate "POSIX";

--
-- LIKE operators don't prune
--
create table like_op_noprune (a text) partition by list (a);
create table like_op_noprune1 partition of like_op_noprune for values in ('ABC');
create table like_op_noprune2 partition of like_op_noprune for values in ('BCD');
explain (costs off) select * from like_op_noprune where a like '%BC';

--
-- tests wherein clause value requires a cross-type comparison function
--
create table lparted_by_int2 (a smallint) partition by list (a);
create table lparted_by_int2_1 partition of lparted_by_int2 for values in (1);
create table lparted_by_int2_16384 partition of lparted_by_int2 for values in (16384);
explain (costs off) select * from lparted_by_int2 where a = 100000000000000;

create table rparted_by_int2 (a smallint) partition by range (a);
create table rparted_by_int2_1 partition of rparted_by_int2 for values from (1) to (10);
create table rparted_by_int2_16384 partition of rparted_by_int2 for values from (10) to (16384);
-- all partitions pruned
explain (costs off) select * from rparted_by_int2 where a > 100000000000000;
create table rparted_by_int2_maxvalue partition of rparted_by_int2 for values from (16384) to (maxvalue);
-- all partitions but rparted_by_int2_maxvalue pruned
explain (costs off) select * from rparted_by_int2 where a > 100000000000000;

drop table lp, coll_pruning, rlp, mc3p, mc2p, boolpart, boolrangep, rp, coll_pruning_multi, like_op_noprune, lparted_by_int2, rparted_by_int2;

--
-- Check that pruning with composite range partitioning works correctly when
-- it must ignore clauses for trailing keys once it has seen a clause with
-- non-inclusive operator for an earlier key
--
create table mc3p (a int, b int, c int) partition by range (a, abs(b), c);
create table mc3p0 partition of mc3p
  for values from (0, 0, 0) to (0, maxvalue, maxvalue);
create table mc3p1 partition of mc3p
  for values from (1, 1, 1) to (2, minvalue, minvalue);
create table mc3p2 partition of mc3p
  for values from (2, minvalue, minvalue) to (3, maxvalue, maxvalue);
insert into mc3p values (0, 1, 1), (1, 1, 1), (2, 1, 1);

explain (analyze, costs off, summary off, timing off)
select * from mc3p where a < 3 and abs(b) = 1;

drop table mc3p;
