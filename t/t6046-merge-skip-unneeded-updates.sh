#!/bin/sh

test_description="merge cases"

# The setup for all of them, pictorially, is:
#
#      A
#      o
#     / \
#  O o   ?
#     \ /
#      o
#      B
#
# To help make it easier to follow the flow of tests, they have been
# divided into sections and each test will start with a quick explanation
# of what commits O, A, and B contain.
#
# Notation:
#    z/{b,c}   means  files z/b and z/c both exist
#    x/d_1     means  file x/d exists with content d1.  (Purpose of the
#                     underscore notation is to differentiate different
#                     files that might be renamed into each other's paths.)

. ./test-lib.sh


###########################################################################
# SECTION 1: Cases involving no renames (one side has subset of changes of
#            the other side)
###########################################################################

# Testcase 1a, Changes on A, subset of changes on B
#   Commit O: b_1
#   Commit A: b_2
#   Commit B: b_3
#   Expected: b_2

test_expect_success '1a-setup: Modify(A)/Modify(B), change on B subset of A' '
	test_create_repo 1a &&
	(
		cd 1a &&

		test_write_lines 1 2 3 4 5 6 7 8 9 10 >b
		git add b &&
		test_tick &&
		git commit -m "O" &&

		git branch O &&
		git branch A &&
		git branch B &&

		git checkout A &&
		test_write_lines 1 2 3 4 5 5.5 6 7 8 9 10 10.5 >b &&
		git add b &&
		test_tick &&
		git commit -m "A" &&

		git checkout B &&
		test_write_lines 1 2 3 4 5 5.5 6 7 8 9 10 >b &&
		git add b &&
		test_tick &&
		git commit -m "B"
	)
'

test_expect_success '1a-check-L: Modify(A)/Modify(B), change on B subset of A' '
	test_when_finished "git -C 1a reset --hard" &&
	(
		cd 1a &&

		git checkout A^0 &&

		GIT_MERGE_VERBOSITY=3 git merge -s recursive B^0 >out 2>err &&

		test_i18ngrep "Skipped" out &&
		test_must_be_empty err &&

		git ls-files -s >index_files &&
		test_line_count = 1 index_files &&

		git rev-parse >actual HEAD:b &&
		git rev-parse >expect A:b &&
		test_cmp expect actual &&

		git hash-object b   >actual &&
		git rev-parse   A:b >expect &&
		test_cmp expect actual
	)
'

test_expect_success '1a-check-R: Modify(A)/Modify(B), change on B subset of A' '
	test_when_finished "git -C 1a reset --hard" &&
	(
		cd 1a &&

		git checkout B^0 &&

		GIT_MERGE_VERBOSITY=3 git merge -s recursive A^0 >out 2>err &&

		test_i18ngrep "Auto-merging" out &&
		test_must_be_empty err &&

		git ls-files -s >index_files &&
		test_line_count = 1 index_files &&

		git rev-parse >actual HEAD:b &&
		git rev-parse >expect A:b &&
		test_cmp expect actual &&

		git hash-object b   >actual &&
		git rev-parse   A:b >expect &&
		test_cmp expect actual
	)
'

###########################################################################
# SECTION 2: Cases involving basic renames
###########################################################################

# Testcase 2a, Changes on A, rename on B
#   Commit O: b_1
#   Commit A: b_2
#   Commit B: c_1
#   Expected: c_2

test_expect_success '2a-setup: Modify(A)/rename(B)' '
	test_create_repo 2a &&
	(
		cd 2a &&

		test_seq 1 10 >b
		git add b &&
		test_tick &&
		git commit -m "O" &&

		git branch O &&
		git branch A &&
		git branch B &&

		git checkout A &&
		test_seq 1 11 > b &&
		git add b &&
		test_tick &&
		git commit -m "A" &&

		git checkout B &&
		git mv b c &&
		test_tick &&
		git commit -m "B"
	)
'

test_expect_success '2a-check-L: Modify/rename, merge into modify side' '
	test_when_finished "git -C 2a reset --hard" &&
	(
		cd 2a &&

		git checkout A^0 &&

		GIT_MERGE_VERBOSITY=3 git merge -s recursive B^0 >out 2>err &&

		test_i18ngrep "Had correct contents" out &&
		test_must_be_empty err &&

		git ls-files -s >index_files &&
		test_line_count = 1 index_files &&

		git rev-parse >actual HEAD:c &&
		git rev-parse >expect A:b &&
		test_cmp expect actual &&

		git hash-object c   >actual &&
		git rev-parse   A:b >expect &&
		test_cmp expect actual &&

		test_must_fail git rev-parse HEAD:b &&
		test_path_is_missing b
	)
'

test_expect_success '2a-check-R: Modify/rename, merge into rename side' '
	test_when_finished "git -C 2a reset --hard" &&
	(
		cd 2a &&

		git checkout B^0 &&

		GIT_MERGE_VERBOSITY=3 git merge -s recursive A^0 >out 2>err &&

		test_i18ngrep "Auto-merging" out &&
		test_must_be_empty err &&

		git ls-files -s >index_files &&
		test_line_count = 1 index_files &&

		git rev-parse >actual HEAD:c &&
		git rev-parse >expect A:b &&
		test_cmp expect actual &&

		git hash-object c   >actual &&
		git rev-parse   A:b >expect &&
		test_cmp expect actual &&

		test_must_fail git rev-parse HEAD:b &&
		test_path_is_missing b
	)
'

# Testcase 2b, Changed and renamed on A, subset of changes on B
#   Commit O: b_1
#   Commit A: c_2
#   Commit B: b_3
#   Expected: c_2

test_expect_success '2b-setup: Modify(A)/Modify(B), change on B subset of A' '
	test_create_repo 2b &&
	(
		cd 2b &&

		test_write_lines 1 2 3 4 5 6 7 8 9 10 >b
		git add b &&
		test_tick &&
		git commit -m "O" &&

		git branch O &&
		git branch A &&
		git branch B &&

		git checkout A &&
		test_write_lines 1 2 3 4 5 5.5 6 7 8 9 10 10.5 >b &&
		git add b &&
		git mv b c &&
		test_tick &&
		git commit -m "A" &&

		git checkout B &&
		test_write_lines 1 2 3 4 5 5.5 6 7 8 9 10 >b &&
		git add b &&
		test_tick &&
		git commit -m "B"
	)
'

test_expect_success '2b-check-L: Modify(A)/Modify(B), change on B subset of A' '
	test_when_finished "git -C 2b reset --hard" &&
	(
		cd 2b &&

		git checkout A^0 &&

		GIT_MERGE_VERBOSITY=3 git merge -s recursive B^0 >out 2>err &&

		test_i18ngrep "Skipped" out &&
		test_must_be_empty err &&

		git ls-files -s >index_files &&
		test_line_count = 1 index_files &&

		git rev-parse >actual HEAD:c &&
		git rev-parse >expect A:c &&
		test_cmp expect actual &&

		git hash-object c   >actual &&
		git rev-parse   A:c >expect &&
		test_cmp expect actual &&

		test_must_fail git rev-parse HEAD:b &&
		test_path_is_missing b
	)
'

test_expect_success '2b-check-R: Modify(A)/Modify(B), change on B subset of A' '
	test_when_finished "git -C 2b reset --hard" &&
	(
		cd 2b &&

		git checkout B^0 &&

		GIT_MERGE_VERBOSITY=3 git merge -s recursive A^0 >out 2>err &&

		test_i18ngrep "Auto-merging" out &&
		test_must_be_empty err &&

		git ls-files -s >index_files &&
		test_line_count = 1 index_files &&

		git rev-parse >actual HEAD:c &&
		git rev-parse >expect A:c &&
		test_cmp expect actual &&

		git hash-object c   >actual &&
		git rev-parse   A:c >expect &&
		test_cmp expect actual &&

		test_must_fail git rev-parse HEAD:b &&
		test_path_is_missing b
	)
'

###########################################################################
# SECTION 3: Cases involving directory renames
#
# NOTE:
#   Directory renames only apply when one side renames a directory, and the
#   other side adds or renames a path into that directory.  Applying the
#   directory rename to that new path creates a new pathname that didn't
#   exist on either side of history.  Thus, it is impossible for the
#   merge contents to already be at the right path, so all of these checks
#   exist just to make sure that updates are not skipped.
###########################################################################

# Testcase 3a, Change + rename into dir foo on A, dir rename foo->bar on B
#   Commit O: bq_1, foo/whatever
#   Commit A: foo/{bq_2, whatever}
#   Commit B: bq_1, bar/whatever
#   Expected: bar/{bq_2, whatever}

test_expect_success '3a-setup: bq_1->foo/bq_2 on A, foo/->bar/ on B' '
	test_create_repo 3a &&
	(
		cd 3a &&

		mkdir foo &&
		test_seq 1 10 >bq &&
		test_write_lines a b c d e f g h i j k >foo/whatever &&
		git add bq foo/whatever &&
		test_tick &&
		git commit -m "O" &&

		git branch O &&
		git branch A &&
		git branch B &&

		git checkout A &&
		test_seq 1 11 > bq &&
		git add bq &&
		git mv bq foo/ &&
		test_tick &&
		git commit -m "A" &&

		git checkout B &&
		git mv foo/ bar/ &&
		test_tick &&
		git commit -m "B"
	)
'

test_expect_success '3a-check-L: bq_1->foo/bq_2 on A, foo/->bar/ on B' '
	test_when_finished "git -C 3a reset --hard" &&
	(
		cd 3a &&

		git checkout A^0 &&

		GIT_MERGE_VERBOSITY=3 git merge -s recursive B^0 >out 2>err &&

		test_i18ngrep "Had correct contents for bar/bq" out &&
		test_must_be_empty err &&

		git ls-files -s >index_files &&
		test_line_count = 2 index_files &&

		git rev-parse >actual HEAD:bar/bq HEAD:bar/whatever &&
		git rev-parse >expect A:foo/bq    A:foo/whatever &&
		test_cmp expect actual &&

		git hash-object bar/bq   bar/whatever   >actual &&
		git rev-parse   A:foo/bq A:foo/whatever >expect &&
		test_cmp expect actual &&

		test_must_fail git rev-parse HEAD:bq HEAD:foo/bq &&
		test_path_is_missing bq foo/bq foo/whatever
	)
'

test_expect_success '3a-check-R: bq_1->foo/bq_2 on A, foo/->bar/ on B' '
	test_when_finished "git -C 3a reset --hard" &&
	(
		cd 3a &&

		git checkout B^0 &&

		GIT_MERGE_VERBOSITY=3 git merge -s recursive A^0 >out 2>err &&

		test_i18ngrep "Auto-merging bar/bq" out &&
		test_must_be_empty err &&

		git ls-files -s >index_files &&
		test_line_count = 2 index_files &&

		git rev-parse >actual HEAD:bar/bq HEAD:bar/whatever &&
		git rev-parse >expect A:foo/bq    A:foo/whatever &&
		test_cmp expect actual &&

		git hash-object bar/bq   bar/whatever   >actual &&
		git rev-parse   A:foo/bq A:foo/whatever >expect &&
		test_cmp expect actual &&

		test_must_fail git rev-parse HEAD:bq HEAD:foo/bq &&
		test_path_is_missing bq foo/bq foo/whatever
	)
'

# Testcase 3b, rename into dir foo on A, dir rename foo->bar + change on B
#   Commit O: bq_1, foo/whatever
#   Commit A: foo/{bq_1, whatever}
#   Commit B: bq_2, bar/whatever
#   Expected: bar/{bq_2, whatever}

test_expect_success '3b-setup: bq_1->foo/bq_2 on A, foo/->bar/ on B' '
	test_create_repo 3b &&
	(
		cd 3b &&

		mkdir foo &&
		test_seq 1 10 >bq &&
		test_write_lines a b c d e f g h i j k >foo/whatever &&
		git add bq foo/whatever &&
		test_tick &&
		git commit -m "O" &&

		git branch O &&
		git branch A &&
		git branch B &&

		git checkout A &&
		git mv bq foo/ &&
		test_tick &&
		git commit -m "A" &&

		git checkout B &&
		test_seq 1 11 > bq &&
		git add bq &&
		git mv foo/ bar/ &&
		test_tick &&
		git commit -m "B"
	)
'

test_expect_success '3b-check-L: bq_1->foo/bq_2 on A, foo/->bar/ on B' '
	test_when_finished "git -C 3b reset --hard" &&
	(
		cd 3b &&

		git checkout A^0 &&

		GIT_MERGE_VERBOSITY=3 git merge -s recursive B^0 >out 2>err &&

		test_i18ngrep "Auto-merging bar/bq" out &&
		test_must_be_empty err &&

		git ls-files -s >index_files &&
		test_line_count = 2 index_files &&

		git rev-parse >actual HEAD:bar/bq HEAD:bar/whatever &&
		git rev-parse >expect B:bq        A:foo/whatever &&
		test_cmp expect actual &&

		git hash-object bar/bq bar/whatever   >actual &&
		git rev-parse   B:bq   A:foo/whatever >expect &&
		test_cmp expect actual &&

		test_must_fail git rev-parse HEAD:bq HEAD:foo/bq &&
		test_path_is_missing bq foo/bq foo/whatever
	)
'

test_expect_success '3b-check-R: bq_1->foo/bq_2 on A, foo/->bar/ on B' '
	test_when_finished "git -C 3b reset --hard" &&
	(
		cd 3b &&

		git checkout B^0 &&

		GIT_MERGE_VERBOSITY=3 git merge -s recursive A^0 >out 2>err &&

		test_i18ngrep "Had correct contents for bar/bq" out &&
		test_must_be_empty err &&

		git ls-files -s >index_files &&
		test_line_count = 2 index_files &&

		git rev-parse >actual HEAD:bar/bq HEAD:bar/whatever &&
		git rev-parse >expect B:bq        A:foo/whatever &&
		test_cmp expect actual &&

		git hash-object bar/bq bar/whatever   >actual &&
		git rev-parse   B:bq   A:foo/whatever >expect &&
		test_cmp expect actual &&

		test_must_fail git rev-parse HEAD:bq HEAD:foo/bq &&
		test_path_is_missing bq foo/bq foo/whatever
	)
'

test_done
